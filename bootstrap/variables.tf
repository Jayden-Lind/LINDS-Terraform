variable "proxmox_endpoint" {
  description = "Proxmox API endpoint for jd-proxmox-02."
  type        = string
  default     = "https://10.0.50.246:8006"
}

variable "proxmox_api_token" {
  description = "Proxmox API token in `user@realm!tokenid=uuid` form. Preferred over username/password."
  type        = string
  default     = null
  sensitive   = true
}

variable "proxmox_username" {
  description = "Proxmox username. Ignored when proxmox_api_token is set."
  type        = string
  default     = null
}

variable "proxmox_password" {
  description = "Proxmox password. Ignored when proxmox_api_token is set."
  type        = string
  default     = null
  sensitive   = true
}

variable "minio_root_user" {
  description = "MinIO root user. Must match the access_key in ../proxmox/backend.conf."
  type        = string
  sensitive   = true
}

variable "minio_root_password" {
  description = "MinIO root password. Must match the secret_key in ../proxmox/backend.conf."
  type        = string
  sensitive   = true
}
