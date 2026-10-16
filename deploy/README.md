# deploy

Merging to `main` applies the Talos and Cilium parts of [`proxmox/`](../proxmox/)
to the cluster. [`linds-tf-deploy`](linds-tf-deploy) runs on `jd-jump-01` from a
systemd user timer: every five minutes it fetches `main`, and when there is a
commit it has not deployed, it runs the README's
[Talos procedure](../README.md#talos) in order:

1. Control plane machine config (`-target=talos_machine_configuration_apply.controlplane`).
2. Worker machine configs, both sites.
3. The Cilium release and its BGP / LB resources. On a version change it
   pulls the new agent image onto one node at a time first.
4. `talosctl upgrade` on every node whose running Talos or schematic differs
   from what its machine config now names: the JD workers, then the LINDS
   workers, then the control plane. Before draining the node that holds the
   Postgres primary, it promotes the replica.

Before the first step, between steps and between nodes, it waits for a
healthy cluster: API ready, every node Ready and schedulable, every Cilium
agent ready and current, Postgres healthy with all instances ready. If the
cluster is not healthy after 15 minutes, it stops.

Each step is a targeted plan, saved and checked before it is applied. A plan
that holds anything outside a short allowlist (the `guard` program at the top
of the script) stops the deploy before it applies anything. The allowlist
covers the Talos configs, schematics and boot ISOs, the Talos VMs' cdrom and
nothing else on them, and the Cilium release. A Talos change that would
replace a VM, a NIC change on a running node, or a new
`talos_machine_secrets` all stop the deploy.

## What it does not do

- **Any other change in `proxmox/`.** At the end of each deploy it plans
  everything without targets, applies none of it, and logs what is left for a
  manual apply. It never runs an untargeted apply. Today one would replace
  JD-Jump-01, the machine the deploy runs on, and create LINDS-Router-01.
- **`bootstrap/` and `packer/`.** `bootstrap/` keeps local state in the
  working checkout and holds the state backend itself.
- **Unseal Vault.** A Talos upgrade drains `vault-0`'s node, and Vault restarts
  sealed. The deploy says so in its log and its GitHub status, and
  `KubePodNotReady` fires after 15 minutes. Unsealing is still by hand.
- **Downgrade Talos, or skip a minor release.** Either stops the deploy before
  it upgrades any node.
- **Check that Talos supports a new Kubernetes minor.** Merging is deploying,
  so check the support matrix before merging one (see `renovate.json5`).

## Why a timer, not GitHub Actions

The deploy has to run inside the network: the state backend, both Proxmox
APIs and the Talos API are only reachable from the LAN. That rules out
GitHub's hosted runners.

The repository is public, which rules out a self-hosted runner. On a public
repository, a runner takes jobs from any workflow a fork's pull request brings,
once that run is approved. That runner would sit on the one machine holding
root to both sites, and every run's log would be public. The timer only ever
runs what is on `main`. It needs nothing from GitHub but a fetch, and its logs
stay on the box.

The `talos_machine` resource in provider 0.12 can upgrade nodes inside a
`terraform apply`. It is not used for two reasons. It applies config in
`AUTO` mode, which reboots a node without draining it when a change needs a
reboot; `apply_mode = "no_reboot"` exists in `talos.tf` to prevent exactly
that. And its drain has no answer to the Postgres primary's
PodDisruptionBudget.

## Install

On `jd-jump-01`, as `jayden` (user lingering is already on):

```shell
git clone https://github.com/Jayden-Lind/LINDS-Terraform.git ~/.local/state/linds-tf-deploy/repo
mkdir -p ~/.config/systemd/user
cp ~/.local/state/linds-tf-deploy/repo/deploy/systemd/linds-tf-deploy.{service,timer} ~/.config/systemd/user/
systemctl --user daemon-reload

~/.local/state/linds-tf-deploy/repo/deploy/linds-tf-deploy --dry-run   # read what it would do
systemctl --user enable --now linds-tf-deploy.timer
```

It reads `~/LINDS-Terraform/proxmox/terraform.tfvars` and `backend.conf`
(override with `LINDS_TF_DEPLOY_TFVARS` / `LINDS_TF_DEPLOY_BACKEND_CONFIG` in
`systemctl --user edit linds-tf-deploy.service`). `gh` must be logged in for
the commit statuses. Everything else it needs comes from the state, or it
downloads it and checks the release checksum: `talosctl` of the release the
control plane runs, and `kubectl-cnpg` of the operator's version.

The first run deploys whatever `main` is. When the cluster already matches
`main`, that run changes nothing.

## Day to day

| To | Do |
| --- | --- |
| Watch a deploy | `journalctl --user -u linds-tf-deploy -f` |
| See how it went | The `deploy/proxmox` status on the commit in GitHub: the current step while it runs, then the result |
| Get told when it fails | Nothing to do: `LindsTerraformDeployFailed` goes to Discord through Alertmanager. It keeps firing while the latest commit's deploy stands failed, and resolves about 20 minutes after a deploy succeeds |
| See what a merge would do | `~/.local/state/linds-tf-deploy/repo/deploy/linds-tf-deploy --dry-run [--ref <branch>]` (a branch or a PR's head, e.g. `renovate/cilium-1.x`) |
| Deploy now instead of within five minutes | `systemctl --user start linds-tf-deploy.service` |
| Pause it | `touch ~/.local/state/linds-tf-deploy/paused` (survives reboots; dry runs still work). `rm` it to resume |
| Retry a failed commit, after fixing the cause | `~/.local/state/linds-tf-deploy/repo/deploy/linds-tf-deploy --retry`. A new commit on `main` retries by itself |

A run that finds nothing new exits at once. A failed commit is not retried by
the timer. A run stopped part-way, by a reboot of the box or a `systemctl
stop`, leaves any node mid-upgrade to finish by itself. The next run waits for
the cluster to be healthy, and stops with an alert if a node is still
cordoned.

The copy of the script that deploys a commit is that commit's own, so a change
to the deploy takes effect with the merge that makes it.

## Changing what it may apply

Add a rule to `guard` in the script: an address pattern, the action lists
allowed (`["update"]`, `["delete", "create"]`, ...), and for an update,
optionally `only`, the attributes it may change. Then add the resource to a
`plan_targets` call. Check the result against a real plan:

```shell
terraform -chdir=proxmox plan -out=/tmp/x.tfplan -target=...
terraform -chdir=proxmox show -json /tmp/x.tfplan |
  jq -r "$(sed -n "/^read -r -d '' guard <<'JQ'/,/^JQ$/{//!p}" deploy/linds-tf-deploy)"
```

It prints one line for each change the deploy would refuse.
