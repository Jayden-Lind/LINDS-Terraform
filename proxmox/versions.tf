terraform {
  # 1.10+ for the S3 backend's use_lockfile.
  required_version = ">= 1.10"

  # State lives in the versitygw S3 gateway running as LXC 107 on
  # jd-proxmox-02. That container is deliberately NOT managed from this root
  # module - see ../bootstrap/README.md for why and how it is managed instead.
  backend "s3" {
    bucket = "tfstate"
    endpoints = {
      s3 = "http://jd-s3-01.linds.com.au:9000"
    }
    key = "linds.tfstate"

    # versitygw rejects a signature for any region but its own (MinIO took
    # anything, and this used to say "main").
    region = "us-east-1"
    # S3-native locking: linds.tfstate.tflock, created with If-None-Match.
    use_lockfile = true

    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.118.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.12.0"
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
