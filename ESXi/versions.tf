terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.5.0"
    }
  }

  #backed stored on the NAS
  backend "local" {
    path = "/mnt/NAS/terraform/terraform.tfstate"
  }

}
