variable "proxmox_endpoint" {
  description = "Proxmox endpoint"
  type        = string
}

variable "proxmox_username" {
  description = "Proxmox username, generally root@pam"
  type        = string
}

variable "proxmox_password" {
  description = "Proxmox Password"
  type        = string
}

variable "proxmox_ssh_username" {
  description = "Proxmox SSH account for copying files"
  type        = string
}

variable "proxmox_ssh_password" {
  description = "Proxmox SSH account password"
  type        = string
}

variable "proxmox_linds_endpoint" {
  description = "Proxmox endpoint for Linds"
  type        = string
  default     = "https://192.168.6.205:8006"
}

variable "datastore" {
  default = "local-lvm"
}

variable "hostname_linds" {
  default = "linds-proxmox-01"
}

variable "datastore_jd" {
  default = "ssd-mixed"
}

variable "hostname" {
  default = "jd-proxmox-02"
}
