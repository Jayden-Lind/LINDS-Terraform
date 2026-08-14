###############################################################################
# Proxmox API
###############################################################################

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint for the JD site (jd-proxmox-02)."
  type        = string
}

variable "proxmox_linds_endpoint" {
  description = "Proxmox API endpoint for the LINDS site (linds-proxmox-01)."
  type        = string
  default     = "https://192.168.6.205:8006"
}

variable "proxmox_api_token" {
  description = <<-EOT
    Proxmox API token in `user@realm!tokenid=uuid` form. Preferred over
    username/password. Create with:
      pveum user token add root@pam terraform --privsep 0
    Leave null to fall back to username/password auth.
  EOT
  type        = string
  default     = null
  sensitive   = true
}

variable "proxmox_username" {
  description = "Proxmox username, generally root@pam. Ignored when proxmox_api_token is set."
  type        = string
  default     = null
}

variable "proxmox_password" {
  description = "Proxmox password. Ignored when proxmox_api_token is set."
  type        = string
  default     = null
  sensitive   = true
}

###############################################################################
# Proxmox SSH (file uploads + ZFS/NFS reconcilers)
###############################################################################

variable "proxmox_ssh_username" {
  description = "SSH account on the Proxmox nodes, used for snippet uploads and host-level reconcilers."
  type        = string
}

variable "proxmox_ssh_password" {
  description = "SSH password. Ignored when proxmox_ssh_private_key is set."
  type        = string
  default     = null
  sensitive   = true
}

variable "proxmox_ssh_private_key" {
  description = "PEM-encoded SSH private key. Preferred over proxmox_ssh_password."
  type        = string
  default     = null
  sensitive   = true
}

###############################################################################
# Guest install media
###############################################################################

variable "windows_server_iso_file_id" {
  description = <<-EOT
    Install ISO for JD-FS-01, as `datastore:iso/filename`. Set this while
    building the guest; null once Windows is installed, which detaches the
    drive and drops the ISO out of the boot order.

    Terraform can only model one optical drive (the provider caps `cdrom` at
    one block), so the virtio-win ISO is attached by hand for the install. See
    the JD-FS-01 block in vms-jd.tf.
  EOT
  type        = string
  default     = null
}

###############################################################################
# Host-level reconcilers
###############################################################################

variable "manage_nfs_exports" {
  description = <<-EOT
    Manage /etc/exports on jd-proxmox-02 over SSH. This is the only host-level
    thing Terraform touches - ZFS pools, datasets, properties, tunables and
    snapshot policy are all left alone. See nfs.tf. Set to false to make this
    root module purely API-driven.
  EOT
  type        = bool
  default     = true
}
