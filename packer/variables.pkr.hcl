###############################################################################
# Ubuntu release
#
# Bump these three together when moving to the next LTS. Checksums come from
# https://releases.ubuntu.com/<version>/SHA256SUMS
###############################################################################

variable "ubuntu_version" {
  type        = string
  description = "Ubuntu LTS point release being built."
  default     = "26.04"
}

variable "iso_url" {
  type        = string
  description = "Installer ISO to download. Proxmox caches it in the ISO storage pool."
  default     = "https://releases.ubuntu.com/26.04/ubuntu-26.04-live-server-amd64.iso"
}

variable "iso_checksum" {
  type        = string
  description = "SHA256 of iso_url."
  default     = "sha256:dec49008a71f6098d0bcfc822021f4d042d5f2db279e4d75bdd981304f1ca5d9"
}

# Previous LTS, for reference when rolling back:
#   ubuntu_version = "24.04.3"
#   iso_url        = "https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-live-server-amd64.iso"
#   iso_checksum   = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"

###############################################################################
# Template placement
###############################################################################

variable "template_name" {
  type        = string
  description = "Name of the resulting Proxmox template."
  default     = "ubuntu"
}

variable "template_vm_id" {
  type        = number
  description = "VMID of the resulting template. proxmox/locals.tf must agree."
  default     = 150
}

variable "disk_size" {
  type        = string
  description = "Template root disk size. Clones grow this via cloud-init."
  default     = "16G"
}

###############################################################################
# Per-site Proxmox connection - see packer_<site>.pkrvars.hcl
###############################################################################

variable "proxmox_node" {
  type        = string
  description = "Proxmox node to build on."
}

variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL, including /api2/json."
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox user, e.g. root@pam. Prefer PKR_VAR_proxmox_username over a vars file."
}

variable "proxmox_password" {
  type        = string
  description = "Proxmox password. Prefer PKR_VAR_proxmox_password over a vars file."
  sensitive   = true
}

variable "proxmox_storage_pool" {
  type        = string
  description = "Datastore for the template disk."
  default     = "local-lvm"
}

variable "disk_format" {
  type        = string
  description = "Disk format. Use raw for LVM-thin and ZFS, qcow2 for directory storage."
  default     = "raw"
}

###############################################################################
# Credentials Packer uses to talk to the guest, matching ./http/user-data
###############################################################################

variable "ssh_username" {
  type        = string
  description = "User created by the autoinstall config."
  default     = "jayden"
}

variable "ssh_password" {
  type        = string
  description = "Password for ssh_username. Prefer PKR_VAR_ssh_password over a vars file."
  sensitive   = true
}
