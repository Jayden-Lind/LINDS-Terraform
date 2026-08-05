terraform {
  required_version = ">= 1.9"

  # LOCAL STATE ON PURPOSE.
  #
  # This root module manages the MinIO container that serves the S3 backend the
  # ../proxmox module stores its state in. Putting that container's own state
  # inside itself would mean:
  #   - a cold start (MinIO down, host rebuilt) leaves you unable to even
  #     `terraform init` the thing you need in order to bring MinIO back, and
  #   - any plan that wanted to replace the container would be writing its own
  #     state to a bucket that stops existing halfway through the apply.
  #
  # So this one module keeps a plain local state file. It is gitignored; if you
  # lose it, `terraform plan` re-adopts the running container from the import
  # blocks in imports.tf and you are back where you started. Nothing here
  # depends on state continuity.

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111.1"
    }
  }
}
