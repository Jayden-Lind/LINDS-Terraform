locals {
  nodes = {
    jd = {
      name    = "jd-proxmox-02"
      address = "10.0.50.246"
    }
    linds = {
      name    = "linds-proxmox-01"
      address = "192.168.6.205"
    }
  }

  # Ubuntu LTS template built by ../packer. Cloned guests reference it by ID.
  ubuntu_template_vm_id = 150

  # Default guest datastores per site.
  datastores = {
    jd    = "ssd-mixed" # ZFS raidz1 on VM pool
    linds = "local-lvm"
  }

  # Speculative-execution mitigations are disabled cluster-wide: this is a
  # single-tenant homelab and the guests are all trusted, so the ~15-30% syscall
  # tax is not worth paying. +pdpe1gb exposes 1 GiB pages, +aes exposes AES-NI.
  guest_cpu_flags = [
    "-md-clear",
    "-pcid",
    "-spec-ctrl",
    "-ssbd",
    "-ibpb",
    "-virt-ssbd",
    "-amd-ssbd",
    "-amd-no-ssb",
    "+pdpe1gb",
    "-hv-tlbflush",
    "-hv-evmcs",
    "+aes",
  ]
}
