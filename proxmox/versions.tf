terraform {
  required_version = ">= 1.9"

  # State lives in the MinIO instance running as LXC 106 on jd-proxmox-02.
  # That container is deliberately NOT managed from this root module - see
  # ../bootstrap/README.md for why and how it is managed instead.
  backend "s3" {
    bucket = "tfstate"
    endpoints = {
      s3 = "http://jd-s3-01.linds.com.au:9000"
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
      version = "~> 0.111.1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.11.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.3"
    }
  }
}
