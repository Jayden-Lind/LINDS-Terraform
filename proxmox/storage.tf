###############################################################################
# Proxmox storage definitions (jd-proxmox-02, standalone node)
#
# These are the PVE-side registrations only - the entries in
# /etc/pve/storage.cfg that tell Proxmox a pool exists and what may live on it.
#
# They do NOT create, modify or destroy the underlying ZFS pools. Removing one
# of these resources runs the equivalent of `pvesm remove`, which deregisters
# the storage and leaves every dataset and zvol exactly where it was. Pool and
# dataset management is entirely out of Terraform's hands; see nfs.tf and the
# ZFS section of README.md.
#
# The provider's zfspool resource does not expose `mountpoint`, so the existing
# /VM, /NAS-SSD and /HDD-20T mountpoints in storage.cfg are left untouched.
###############################################################################

resource "proxmox_storage_directory" "local" {
  id      = "local"
  path    = "/var/lib/vz"
  content = ["snippets", "backup", "iso", "vztmpl"]
  shared  = false
}

resource "proxmox_storage_lvmthin" "local_lvm" {
  id           = "local-lvm"
  volume_group = "pve"
  thin_pool    = "data"
  content      = ["rootdir", "images"]
}

# VM pool: 3-wide raidz1 across one 2 TB and two 600 GB SATA SSDs.
# Backs every guest boot disk on this node, plus the MinIO and NFS datasets.
resource "proxmox_storage_zfspool" "ssd_mixed" {
  id       = "ssd-mixed"
  zfs_pool = "VM"
  content  = ["rootdir", "images"]
}

# NAS-SSD: 5-wide raidz1 of 4 TB SATA SSDs.
# Single consumer: the 14.2 TiB zvol attached to JD-DC-01 as scsi1.
resource "proxmox_storage_zfspool" "nas_ssd" {
  id       = "NAS-SSD"
  zfs_pool = "NAS-SSD"
  content  = ["rootdir", "images"]
  nodes    = [local.nodes.jd.name]
}

# HDD-20T: 2-way mirror of 20 TB spinners, exported over NFS as /mnt/HDD.
resource "proxmox_storage_zfspool" "hdd_20t" {
  id       = "hdd-20t"
  zfs_pool = "HDD-20T"
  content  = ["rootdir", "images"]
  nodes    = [local.nodes.jd.name]
}

# Orphan: pinned to jd-proxmox-01, a node that no longer exists. Declared here
# so it shows up in state rather than being silently invisible; safe to remove
# with `pvesm remove NAS` once you are happy it is dead.
resource "proxmox_storage_lvmthin" "nas_orphan" {
  id           = "NAS"
  volume_group = "NAS"
  thin_pool    = "NAS"
  content      = ["rootdir", "images"]
  nodes        = ["jd-proxmox-01"]
}
