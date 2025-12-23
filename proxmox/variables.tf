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
