###############################################################################
# jd-s3-01 (LXC 107) - S3 backend for ../proxmox
#
# An unprivileged, OCI-image-based container running versitygw (Versity S3
# Gateway, image docker.io/versity/versitygw) over /mnt/NAS/s3 (dataset
# VM/truenas-nas/s3, daily sanoid snapshots, pulled to linds-truenas-01).
# Reachable at http://10.0.53.20:9000, published as jd-s3-01.linds.com.au;
# web UI on :9002.
#
# The posix backend stores every object as an ordinary file under
# /mnt/NAS/s3/buckets/<bucket>/<key>, metadata in xattrs, so a snapshot or the
# LINDS replica can be read without a running gateway. Accounts for the
# clients live in /mnt/NAS/s3/iam/users.json (internal IAM, plain text, 0600).
#
# It replaced MinIO (LXC 106, archived upstream) on 2026-10-17 and took over
# that container's address and MAC, so no client or ARP cache had to change.
###############################################################################

resource "proxmox_virtual_environment_container" "s3" {
  vm_id       = 107
  node_name   = "jd-proxmox-02"
  description = "versitygw S3 gateway (OCI image, unprivileged). Holds the tfstate bucket for ../proxmox, the CNPG backups and Loki. Data: VM/truenas-nas/s3 at /data."

  unprivileged  = true
  start_on_boot = true
  started       = true

  cpu {
    cores = 2
  }

  memory {
    dedicated = 1024
    swap      = 256
  }

  console {
    type = "console"
  }

  startup {
    order = 2
  }

  initialization {
    hostname = "jd-s3-01"

    # The image's own entrypoint; it builds the versitygw command line from
    # the VGW_* variables below.
    entrypoint = "/usr/local/bin/docker-entrypoint.sh"

    dns {
      servers = ["10.0.50.1"]
    }

    ip_config {
      ipv4 {
        address = "10.0.53.20/24"
        gateway = "10.0.53.1"
      }
    }
  }

  disk {
    datastore_id = "ssd-mixed"
    size         = 4
  }

  # The data directory, bind-mounted from the ZFS dataset. No `size` - a bind
  # mount has no volume of its own, and setting one forces replacement.
  # Owned by uid/gid 100000 on the host, i.e. root in the container.
  mount_point {
    volume = "/mnt/NAS/s3"
    path   = "/data"
  }

  network_interface {
    name         = "eth0"
    bridge       = "vmbr0"
    mac_address  = "BC:24:11:18:E7:A7" # MinIO's, kept so neighbours' ARP entries stayed valid
    vlan_id      = 53
    host_managed = true
  }

  environment_variables = {
    PATH = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

    VGW_BACKEND     = "posix"
    VGW_BACKEND_ARG = "/data/buckets"
    VGW_IAM_DIR     = "/data/iam"
    VGW_PORT        = ":9000"
    # Every SigV4 request must be signed for exactly this region (unlike
    # MinIO, which ignored it). Loki, the barman plugin and the ../proxmox
    # backend are all set to us-east-1.
    VGW_REGION     = "us-east-1"
    VGW_HEALTH     = "/health"
    VGW_QUIET      = "true"
    VGW_KEEP_ALIVE = "true"

    # By default each object is written as an O_TMPFILE and published with
    # linkat(), which on ZFS waits for the transaction group to sync: ~33 ms
    # per object, serialised, so small objects topped out at ~25-30/s however
    # many clients wrote at once (measured 2026-10-17). A named temp file +
    # rename() costs ~0.02 ms. FSYNC then makes each acknowledged object
    # durable through the ZIL (7 ms alone, ~490 objects/s at 16 in parallel),
    # which the slow linkat had been providing as a side effect - barman
    # deletes a WAL segment once the store has acknowledged it.
    VGW_DISABLE_OTMP = "true"
    VGW_FSYNC        = "true"

    VGW_WEBUI_PORT        = ":9002"
    VGW_WEBUI_GATEWAYS    = "http://jd-s3-01.linds.com.au:9000"
    VGW_CORS_ALLOW_ORIGIN = "http://jd-s3-01.linds.com.au:9002"

    ROOT_ACCESS_KEY_ID     = var.s3_root_access_key
    ROOT_SECRET_ACCESS_KEY = var.s3_root_secret_key
  }

  lifecycle {
    # Deleting this container destroys the Terraform state for every other
    # module in this repo. It does not get replaced by accident.
    prevent_destroy = true

    # This is an OCI-image container, so there is no template file to point
    # `operating_system.template_file_id` at - but the provider requires that
    # argument whenever the block is present, and omitting the block reads as
    # "remove the OS", which forces replacement. Ignoring it is the only way to
    # express "this was created from an OCI image and never changes".
    ignore_changes = [operating_system]
  }
}
