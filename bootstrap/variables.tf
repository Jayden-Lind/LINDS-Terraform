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

variable "s3_root_access_key" {
  description = "versitygw root access key (ROOT_ACCESS_KEY_ID). Admin only; the clients have their own accounts."
  type        = string
  sensitive   = true
}

variable "s3_root_secret_key" {
  description = "versitygw root secret key (ROOT_SECRET_ACCESS_KEY)."
  type        = string
  sensitive   = true
}
