locals {
  # Prefer an API token when one is supplied (bpg's recommended auth method:
  # scoped, revocable, and never sends the root password over the wire).
  # Fall back to username/password so existing tfvars keep working.
  use_api_token = var.proxmox_api_token != null && var.proxmox_api_token != ""
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = local.use_api_token ? var.proxmox_api_token : null
  username  = local.use_api_token ? null : var.proxmox_username
  password  = local.use_api_token ? null : var.proxmox_password
  insecure  = true
  tmp_dir   = "/var/tmp"

  # SSH is used for file uploads (snippets) and for the ZFS/NFS reconcilers.
  ssh {
    username    = var.proxmox_ssh_username
    password    = var.proxmox_ssh_private_key != null ? null : var.proxmox_ssh_password
    private_key = var.proxmox_ssh_private_key

    node {
      name    = local.nodes.jd.name
      address = local.nodes.jd.address
    }
  }
}

provider "proxmox" {
  alias     = "linds"
  endpoint  = var.proxmox_linds_endpoint
  api_token = local.use_api_token ? var.proxmox_api_token : null
  username  = local.use_api_token ? null : var.proxmox_username
  password  = local.use_api_token ? null : var.proxmox_password
  insecure  = true
  tmp_dir   = "/var/tmp"

  ssh {
    username    = var.proxmox_ssh_username
    password    = var.proxmox_ssh_private_key != null ? null : var.proxmox_ssh_password
    private_key = var.proxmox_ssh_private_key

    node {
      name    = local.nodes.linds.name
      address = local.nodes.linds.address
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
