###############################################################################
# What to install
###############################################################################

variable "windows_iso_file" {
  type        = string
  description = "Windows Server ISO, already in the node's ISO storage, as <storage>:iso/<file>."
}

variable "windows_image_name" {
  type        = string
  description = "Image to install, exactly as `dism /Get-WimInfo` names it on that ISO."
  default     = "Windows Server 2025 Standard Evaluation (Desktop Experience)"
}

# Do not use a version that Proxmox lists as known to cause issues: 0.1.215 to
# 0.1.262, and 0.1.285 (https://pve.proxmox.com/wiki/Windows_VirtIO_Drivers).
# On Windows Server 2025 the 0.1.285 vioscsi and viostor drivers can return the
# wrong data under load. 0.1.302 has the upstream fix.
variable "virtio_iso_file" {
  type        = string
  description = "virtio-win driver ISO, already in the node's ISO storage."
  default     = "local:iso/virtio-win-0.1.302.iso"
}

variable "virtio_os_dir" {
  type        = string
  description = "Per-OS driver folder on the virtio ISO (2k25 for Server 2025, 2k22 for 2022)."
  default     = "2k25"
}

variable "time_zone" {
  type        = string
  description = "Windows time zone name for the template and its clones."
  default     = "AUS Eastern Standard Time"
}

###############################################################################
# Template placement
###############################################################################

variable "template_name" {
  type        = string
  description = "Name of the resulting Proxmox template."
  default     = "windows-server-2025"
}

variable "template_vm_id" {
  type        = number
  description = "VMID of the resulting template. proxmox/locals.tf must agree."
  default     = 160
}

variable "disk_size" {
  type        = string
  description = "Template system disk. Clones grow it; Windows extends C: into the rest."
  default     = "60G"
}

variable "build_vlan" {
  type        = number
  description = "VLAN the build VM sits on, or 0 for untagged. It needs DHCP, and Packer must reach it on 5985."
  default     = 300
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
  description = "Datastore for the template disk and its EFI variable store."
  default     = "local-lvm"
}

variable "disk_format" {
  type        = string
  description = "Disk format. Use raw for LVM-thin and ZFS, qcow2 for directory storage."
  default     = "raw"
}

###############################################################################
# The local Administrator password
#
# Used for the build, and left as the password every clone starts with, so
# Ansible can make its first connection. Keep it in the Ansible vault
# (windows_bootstrap_password) and pass it as PKR_VAR_admin_password.
###############################################################################

variable "admin_password" {
  type        = string
  description = "Local Administrator password for the build and for fresh clones. Letters and digits only: it is written into XML and passed on a command line."
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9]{16,}$", var.admin_password))
    error_message = "The admin_password must be at least 16 letters and digits, nothing else."
  }
}

variable "winrm_allowed_sources" {
  type        = string
  description = "Comma-separated addresses or ranges allowed to reach WinRM on a fresh clone, before it has joined the domain."
  default     = "10.0.50.0/24,10.3.1.0/24"
}
