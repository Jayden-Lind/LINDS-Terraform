# deploy

Merging to `main` applies the Talos and Cilium parts of [`proxmox/`](../proxmox/)
to the cluster. [`linds-tf-deploy`](linds-tf-deploy) runs on `jd-jump-01` from a
systemd user timer: every six hours it fetches `main`, and when there is a
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

Before you merge, each pull request shows what the merge does. See
[Previews of pull requests](#previews-of-pull-requests).

## Previews of pull requests

Every five minutes, `linds-tf-deploy --previews` looks at the open pull
requests. It previews a pull request from a branch of this repository. It
never previews a pull request from a fork.

For each pull request, it does these steps:

1. It gets the commit that GitHub makes for a merge into `main`. If the pull
   request has a conflict with `main`, it sets the status `preview/proxmox`
   to error and stops.
2. If the pull request changes nothing under `proxmox/`, the status says that
   a merge deploys nothing.
3. If not, it does a dry run of the merge commit, the same as
   `--dry-run --ref`. It also does a dry run of `main`, once for each commit
   of `main`, to compare with.
4. It sets the commit status `preview/proxmox`: what the deploy applies, or
   why it stops.
5. It writes one comment on the pull request: the changes of each step, the
   Talos upgrades, and the changes left for a manual apply. It shows only
   what the pull request adds to `main`. A later preview changes the same
   comment.

The preview runs again when the pull request or `main` changes. It names
resources only. The repository is public, and a plan can hold secrets, so the
plans stay in `~/.local/state/linds-tf-preview/logs/` on `jd-jump-01`.

The previews run from main's copy of the script, never from the copy in a
pull request. They use their own state folder,
`~/.local/state/linds-tf-preview/`, so a preview never holds the lock of the
deploy. Their plans do not take the state lock.

**NOTE:** A dry run runs the Terraform code of the pull request: `terraform
init` gets its providers, and a data source runs in the plan. Previews run
only for branches of this repository, so only code that you or Renovate push
runs.

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

For the previews of pull requests, a second clone and timer:

```shell
git clone https://github.com/Jayden-Lind/LINDS-Terraform.git ~/.local/state/linds-tf-preview/repo
cp ~/.local/state/linds-tf-preview/repo/deploy/systemd/linds-tf-preview.{service,timer} ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now linds-tf-preview.timer
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
| Watch a deploy | `journalctl --user -t linds-tf-deploy -f` (by identifier: `-u` misses the lines short-lived commands print, which journald cannot tie to the unit once they exit) |
| See how it went | The `deploy/proxmox` status on the commit in GitHub: the current step while it runs, then the result |
| Get told when it fails | Nothing to do: `LindsTerraformDeployFailed` goes to Discord through Alertmanager. It keeps firing while the latest commit's deploy stands failed, and resolves when a later deploy succeeds |
| See what a merge would do | The comment and the `preview/proxmox` status on the pull request. By hand: `~/.local/state/linds-tf-deploy/repo/deploy/linds-tf-deploy --dry-run [--ref <branch>]` (a branch or a PR's head, e.g. `renovate/cilium-1.x`) |
| Preview the pull requests now | `systemctl --user start linds-tf-preview.service` |
| Preview all pull requests again | `systemctl --user start linds-tf-preview.service` after `rm ~/.local/state/linds-tf-preview/previews.json` |
| Read the log of the previews | `journalctl --user -t linds-tf-preview -f`. The full plans are in `~/.local/state/linds-tf-preview/logs/` |
| Deploy now instead of at the next check (up to six hours) | `systemctl --user start linds-tf-deploy.service` |
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
