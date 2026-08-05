# bootstrap

Manages **LXC 106 (`jd-minio-01`)** — the MinIO instance that serves the S3
backend everything else stores its Terraform state in.

## Why this is a separate root module

`../proxmox` keeps its state in a bucket served by this container, which runs on
the very host that module manages. Managing the container from there would mean:

- **Cold start is impossible.** Rebuild the host, and you cannot `terraform init`
  the module you need in order to bring MinIO back, because `init` wants to talk
  to MinIO.
- **A replace would eat its own state.** Any plan that decided to recreate the
  container would be writing state to a bucket that stops existing mid-apply.

So this module — and only this module — uses a **local state file**. It is
gitignored. Losing it is a non-event: `imports.tf` re-adopts the running
container, so `terraform plan` reads what is live instead of proposing to build
a second one.

The container is also marked `prevent_destroy`. Terraform will refuse to plan
anything that would remove it rather than doing it and telling you afterwards.

## Usage

```shell
cd bootstrap
terraform init
terraform plan
```

`terraform.tfvars` needs, at minimum:

```hcl
proxmox_api_token   = "root@pam!terraform=..."
minio_root_user     = "..."
minio_root_password = "..."
```

`minio_root_user` / `minio_root_password` must match `access_key` /
`secret_key` in `../proxmox/backend.conf`.

## Disaster recovery order

1. Proxmox host back up, `VM` pool imported, `VM/truenas-nas/minio` present.
2. `cd bootstrap && terraform apply` — MinIO comes back on 10.0.53.20:9000.
3. Restore the `tfstate` bucket contents (or accept the loss and re-import).
4. `cd ../proxmox && terraform init -backend-config=backend.conf`.

Step 3 is the one that bites. The dataset is snapshotted hourly by sanoid
(`VM/truenas-nas` recursive, 24 hourly / 14 daily), so a lost bucket is a
`zfs rollback` away — but that is a snapshot on the same pool as the thing it is
protecting. An off-box copy of `linds.tfstate` is worth having.
