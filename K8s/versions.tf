terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.21.1"
    }
  }
  backend "local" {
    path = "/mnt/NAS/terraform/terraform_k8.tfstate"
  }
}

provider "kubernetes" {
  host = "https://jd-kube-01:6443"

  client_certificate     = file("client.cer")
  client_key             = file("client.key")
  cluster_ca_certificate = file("ca.cer")
}


