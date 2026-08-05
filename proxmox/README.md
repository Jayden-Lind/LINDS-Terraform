# proxmox

Everything on `jd-proxmox-02` (10.0.50.246) plus the guests on `linds-proxmox-01`,
and the Talos/Cilium cluster that runs across both.

## Layout

| File | What lives there |
| --- | --- |
| `versions.tf` | Terraform + provider version constraints, S3 backend |
| `providers.tf` | Proxmox (both sites), Helm, Kubernetes provider config |
| `variables.tf` | Input variables |
| `locals.tf` | Node addresses, datastores, shared guest CPU flags |
| `storage.tf` | Proxmox storage *registrations* (`local`, `local-lvm`, the three ZFS pools) |
| `nfs.tf` | `/etc/exports` — the only host-level thing Terraform writes |
| `templates/` | Rendered scripts used by `nfs.tf` |
| `network.tf` | `vmbr0` / `vmbr1` / `vmbr0.53` |
| `vms-jd.tf` | JD site guests |
| `vms-linds.tf` | LINDS site guests |
| `modules/talos-node/` | The Talos VM shape, used three times |
| `talos-schematic.tf` | Image factory schematics (AMD + Intel) |
| `talos.tf` | Machine config, bootstrap, kubeconfig |
| `cilium.tf` | Helm release and BGP custom resources |
| `imports.tf` | Adoption of pre-existing infrastructure |
| `removed.tf` | State-only removals for the deprecated network resource names |
| `moved.tf` | Address migrations from the pre-refactor layout |

## Usage

```shell
terraform init -backend-config=backend.conf
terraform plan
```

`backend.conf` and `terraform.tfvars` are gitignored; copy the `.example` files.

Auth prefers an API token. Create one and set `proxmox_api_token`:

```shell
pveum user token add root@pam terraform --privsep 0
```

Username/password still works if the token is left unset.

## Things worth knowing

**State lives in MinIO, which runs on the host this module manages.** The MinIO
container is therefore *not* managed here — see [`../bootstrap`](../bootstrap).

**ZFS is not managed by Terraform.** Deliberately. The pools hold live data,
they were built by hand, and no provider can touch them safely — so nothing in
this module creates, alters or destroys a pool, dataset, property or snapshot.
`storage.tf` only registers the pools with Proxmox; deleting one of those
resources deregisters the storage and leaves the data untouched.

The one exception is `/etc/exports`, managed in `nfs.tf` over SSH because it has
no API. Set `manage_nfs_exports = false` to make this module purely
API-driven.

The current ZFS layout, recorded here for reference — change it with `zfs` on
the host, not from here:

| Pool | Topology | Notes |
| --- | --- | --- |
| `VM` | raidz1, 1×2TB + 2×600GB SATA SSD | `ashift=12`, `autotrim=on`. All guest disks |
| `NAS-SSD` | raidz1, 5×4TB Samsung 870 EVO | `ashift=12`, `autotrim=off`. Only JD-DC-01's bulk zvol |
| `HDD-20T` | mirror, 2×20TB Seagate Exos | `ashift=12`, `autotrim=on`. Bulk media |

| Dataset | Non-inherited properties |
| --- | --- |
| `VM` | `compression=zstd atime=off xattr=sa` |
| `VM/truenas-nas` | `mountpoint=/mnt/NAS recordsize=1M compression=zstd atime=off acltype=posix` |
| `VM/truenas-nas/minio` | inherits — backs the MinIO LXC, i.e. this repo's tfstate |
| `VM/truenas-nas/k8s-iscsi{,/s,/v}` | inherits — democratic-csi owns everything below |
| `NAS-SSD` | `compression=zstd atime=off` |
| `HDD-20T` | `mountpoint=/HDD-20T recordsize=1M compression=off atime=off primarycache=metadata logbias=throughput sync=disabled` |
| `HDD-20T/data` | `mountpoint=/mnt/HDD recordsize=1M compression=off atime=off direct=always` |

ARC is capped at 64 GiB with a 16 GiB floor; vdev queue depths and dirty-data
headroom are raised in `/etc/modprobe.d/zfs.conf`. Snapshots are sanoid's job
(`/etc/sanoid/sanoid.conf`): `VM/truenas-nas` recursive, 24 hourly / 14 daily.

**Mitigations are off everywhere.** Both the guest CPU flags
(`locals.tf`) and the Talos kernel args (`talos-schematic.tf`) disable
speculative-execution mitigations and most kernel hardening. That is a
deliberate single-tenant homelab tradeoff; do not lift these files into
anything that runs untrusted code.

**Talos schematic IDs are content hashes.** Reordering `extraKernelArgs`
changes the installer image reference on every node. Append, do not reshuffle.

**`JD-VyOS-01` advertises a guest agent it does not run.** `agent: 1` is set on
VM 1100 but VyOS never starts `qemu-guest-agent`, so any read of that VM blocks
for the provider's full agent timeout. The config works around it with
`wait_for_ip { disabled = true }`, but the *initial import* has no config to
read and will sit there. Either enable the agent in VyOS
(`set service qemu-guest-agent`) or clear the flag (`qm set 1100 --agent 0`)
before adopting it.

**`JD-Minecraft-01` is the odd one out.** SeaBIOS, i440fx, LSI SCSI, no NIC, and
an orphaned `unused0` volume on `local-lvm` that Terraform does not model. Its
`scsi_hardware` is pinned to `lsi` so Terraform does not move the controller out
from under the installed guest.

**The `NAS` storage entry is dead.** It is pinned to `jd-proxmox-01`, a node that
no longer exists. Declared in `storage.tf` so it is visible rather than silently
lurking; remove with `pvesm remove NAS` when you are sure.
