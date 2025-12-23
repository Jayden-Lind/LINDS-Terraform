terraform {
  backend "s3" {
    bucket = "tfstate"
    endpoints = {
      s3 = "http://jd-truenas-01.linds.com.au:9000"
    }
    key = "linds.tfstate"


    region                      = "main"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.89.1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
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
  alias    = "linds"
  endpoint = "https://192.168.6.205:8006"
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = true
  tmp_dir  = "/var/tmp"
  ssh {
    username = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
    node {
      name    = "linds-proxmox-01"
      address = "192.168.6.205"
    }
  }
}

provider "helm" {
  kubernetes = {
    host                   = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
    client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
  }
}

provider "kubernetes" {
  host                   = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
  client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
}