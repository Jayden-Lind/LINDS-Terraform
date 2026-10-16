# bootstrap

Manages **LXC 107 (`jd-s3-01`)** — the [versitygw](https://github.com/versity/versitygw)
S3 gateway that serves the S3 backend everything else stores its Terraform
state in. It also holds the CNPG barman backups (`postgresql-backup`) and
Loki's chunks (`loki-chunks`, `loki-ruler`).

It replaced MinIO (LXC 106, `jd-minio-01`) on 2026-10-17: MinIO's community
edition was archived upstream and its last image dates from 2025-09-07. The new
container took over 10.0.53.20 and MinIO's MAC address, so clients only saw the
server change.

## Why this is a separate root module

`../proxmox` keeps its state in a bucket served by this container, which runs on
the very host that module manages. Managing the container from there would mean:

- **Cold start is impossible.** Rebuild the host, and you cannot `terraform init`
  the module you need in order to bring the S3 server back, because `init`
  wants to talk to it.
- **A replace would eat its own state.** Any plan that decided to recreate the
  container would be writing state to a bucket that stops existing mid-apply.

So this module — and only this module — uses a **local state file**. It is
gitignored. Losing it is a non-event: `imports.tf` re-adopts the running
container, so `terraform plan` reads what is live instead of proposing to build
a second one.

The container is also marked `prevent_destroy`. Terraform will refuse to plan
anything that would remove it rather than doing it and telling you afterwards.

## How it stores things

- Dataset `VM/truenas-nas/s3`, mounted at `/mnt/NAS/s3` on the host and
  `/data` in the container, owned by uid/gid 100000 (container root).
- `/data/buckets/<bucket>/<key>` — every object is an ordinary file, its
  metadata in xattrs (`xattr=sa` on the pool). A bucket can be read, copied or
  restored with plain file tools, from a snapshot or from the LINDS replica.
- `/data/iam/users.json` — the internal IAM: one account per client, each the
  owner of its own bucket(s). Plain text, mode 0600.
- Objects are written to a named temp file and published with `rename()`,
  then fsynced (`VGW_DISABLE_OTMP`, `VGW_FSYNC`). The default, an `O_TMPFILE`
  published with `linkat()`, waits for a ZFS transaction-group sync on every
  object: 33 ms each, serialised, so small objects stalled at ~25–30/s. With
  rename + fsync a PUT takes ~7 ms and parallel writers reach ~490 objects/s,
  and an acknowledged object is still on disk.
- Snapshots: sanoid, `VM/truenas-nas` recursive, **daily only, 14 kept**
  (`template_ssd_short`). linds-truenas-01 pulls the dailies every night, so the
  off-site copy is 14–38 h behind.

Every request must be SigV4-signed for region **`us-east-1`** (`VGW_REGION`).
MinIO ignored the region; versitygw answers anything else with
`AuthorizationHeaderMalformed`. Loki sets it explicitly, the barman plugin
(boto3) uses it by default, and `../proxmox` sets it in its backend block.

## Accounts

| Account | Role | Owns | Used by |
| --- | --- | --- | --- |
| root (`ROOT_ACCESS_KEY_ID`) | admin | — | admin CLI only |
| `terraform` | user | `tfstate` | `../proxmox/backend.conf` |
| `cnpg` | user | `postgresql-backup` | Vault `linds-keyvault/cnpg-s3-creds` |
| `loki` | user | `loki-chunks`, `loki-ruler` | Vault `linds-keyvault/loki-access-creds` |

Manage them from the host; the admin CLI falls back to the container's root
credentials:

```shell
pct exec 107 -- versitygw admin -er http://127.0.0.1:9000 list-users
pct exec 107 -- versitygw admin -er http://127.0.0.1:9000 list-buckets
pct exec 107 -- versitygw admin -er http://127.0.0.1:9000 create-user --access <key> --secret <secret> --role user
pct exec 107 -- versitygw admin -er http://127.0.0.1:9000 change-bucket-owner --bucket <bucket> --owner <key>
```

The web UI is at http://jd-s3-01.linds.com.au:9002 (log in with an account's
keys).

## Usage

```shell
cd bootstrap
terraform init
terraform plan
```

`terraform.tfvars` needs, at minimum:

```hcl
proxmox_api_token  = "root@pam!terraform=..."
s3_root_access_key = "..."
s3_root_secret_key = "..."
```

## Disaster recovery order

1. Proxmox host back up, `VM` pool imported, `VM/truenas-nas/s3` present.
2. Stage the image: `pvesh create /nodes/jd-proxmox-02/storage/local/oci-registry-pull --reference docker.io/versity/versitygw:<tag> --filename versitygw_<tag>`.
3. Create the container from it with `pct create 107 local:vztmpl/versitygw_<tag>.tar ...`
   (the settings in `main.tf`), then `cd bootstrap && terraform apply` to
   adopt it and set the rest. The gateway comes back on 10.0.53.20:9000 with
   its buckets and accounts, both of which live on the dataset.
4. `cd ../proxmox && terraform init -backend-config=backend.conf`.

If the dataset itself is gone, restore it from a sanoid snapshot or from
`NAS/s3` on linds-truenas-01 (`zfs send` back, or copy the files: they are
plain files). For `linds.tfstate` alone, any snapshot's
`buckets/tfstate/linds.tfstate` is the state file.
