terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.62.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = true
  tmp_dir  = "/var/tmp"
  ssh {
    username = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
    node {
      name    = "jd-proxmox-01"
      address = "10.0.50.245"
    }
  }
}

provider "proxmox" {
  alias = "linds"
  endpoint = "https://192.168.6.205:8006"
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = true
  tmp_dir = "/var/tmp"
  ssh {
    username = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
    node {
      name    = "linds-proxmox-01"
      address = "192.168.6.205"
    }
  }
}