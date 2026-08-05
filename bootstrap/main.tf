###############################################################################
# jd-minio-01 (LXC 106) - S3 backend for ../proxmox
#
# An unprivileged, OCI-image-based container running MinIO against
# /mnt/NAS/minio (dataset VM/truenas-nas/minio, snapshotted hourly by sanoid).
# Reachable at http://10.0.53.20:9000, published as jd-s3-01.linds.com.au.
#
# The uid/gid 473 idmap lines and the OCI entrypoint are what make this thing
# work; if a plan ever wants to change them, stop and read the config on the
# host first.
###############################################################################

resource "proxmox_virtual_environment_container" "minio" {
  vm_id     = 106
  node_name = "jd-proxmox-02"
  # "MinIO S3 OCI, unprivileged, IP 10.0.50.20"
  description = "MinIO S3 OCI, unprivileged. Holds the tfstate bucket for ../proxmox."

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
    hostname = "jd-minio-01"

    # OCI entrypoint. Without this the container comes up doing nothing.
    entrypoint = "/usr/bin/docker-entrypoint.sh minio server /export --console-address :9002"

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

  # The MinIO data directory, bind-mounted from the ZFS dataset. No `size` -
  # a bind mount has no volume of its own, and setting one forces replacement.
  mount_point {
    volume = "/mnt/NAS/minio"
    path   = "/export"
  }

  network_interface {
    name         = "eth0"
    bridge       = "vmbr0"
    mac_address  = "BC:24:11:18:E7:A7"
    vlan_id      = 53
    host_managed = true
  }

  environment_variables = {
    PATH                         = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    MINIO_ACCESS_KEY_FILE        = "access_key"
    MINIO_SECRET_KEY_FILE        = "secret_key"
    MINIO_ROOT_USER_FILE         = "access_key"
    MINIO_ROOT_PASSWORD_FILE     = "secret_key"
    MINIO_KMS_SECRET_KEY_FILE    = "kms_master_key"
    MINIO_UPDATE_MINISIGN_PUBKEY = "RWTx5Zr1tiHQLwG9keckT0c45M3AGeHD6IvimQHpyRywVWGbP1aVSGav"
    MINIO_CONFIG_ENV_FILE        = "config.env"
    MC_CONFIG_DIR                = "/tmp/.mc"
    MINIO_ROOT_USER              = var.minio_root_user
    MINIO_ROOT_PASSWORD          = var.minio_root_password
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
