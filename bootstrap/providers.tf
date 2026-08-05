locals {
  use_api_token = var.proxmox_api_token != null && var.proxmox_api_token != ""
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = local.use_api_token ? var.proxmox_api_token : null
  username  = local.use_api_token ? null : var.proxmox_username
  password  = local.use_api_token ? null : var.proxmox_password
  insecure  = true
}
