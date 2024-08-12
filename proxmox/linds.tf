variable "linds_kubernetes" {
  type = list(object({
    name  = string
    cores = string
    ram   = number
  }))

  default = [
    {
      name  = "linds-kube-01"
      cores = "4"
      ram   = 4096
    },
    {
      name  = "linds-kube-02"
      cores = "4"
      ram   = 8192
    },
  ]
}

variable "hostname_linds" {
  default = "linds-proxmox-01"
}

resource "proxmox_virtual_environment_vm" "kubernetes_nodes_linds" {
  provider = proxmox.linds
  count      = length(var.linds_kubernetes)
  depends_on = [proxmox_virtual_environment_file.kube_cloud_config]
  name       = var.linds_kubernetes[count.index].name
  tags       = ["kubernetes"]
  node_name  = var.hostname_linds

  cpu {
    type  = "host"
    cores = var.linds_kubernetes[count.index].cores
    flags = [
      "-md-clear",
      "-pcid",
      "-spec-ctrl",
      "-ssbd",
      "-ibpb",
      "-virt-ssbd",
      "-amd-ssbd",
      "-amd-no-ssb",
      "-pdpe1gb",
      "-hv-tlbflush",
      "-hv-evmcs",
      "+aes",
    ]
  }
  memory {
    dedicated = var.linds_kubernetes[count.index].ram
  }

  bios = "ovmf"

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = "20"
    iothread     = false
    discard      = "ignore"
    cache        = "none"
  }

  machine = "q35"

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = "300"
    firewall = false
  }

  clone {
    vm_id = 150
  }

  operating_system {
    type = "l26"
  }
  lifecycle {
    ignore_changes = [
      clone
    ]
  }
}

resource "proxmox_virtual_environment_vm" "linds-plex-01" {
  provider  = proxmox.linds
  name       = "LINDS-Plex-01"
  node_name  = var.hostname_linds

  cpu {
    type  = "host"
    cores = "4"
  }
  memory {
    dedicated = "4096"
  }

  bios = "ovmf"

  machine = "q35"

  scsi_hardware = "virtio-scsi-single"

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = "300"
  }
  lifecycle {
    ignore_changes = [
      clone
    ]
  }
}

resource "proxmox_virtual_environment_vm" "linds-torrent-01" {
  provider  = proxmox.linds
  name       = "LINDS-Torrent-01"

  node_name  = var.hostname_linds

  cpu {
    type  = "host"
    cores = "4"
  }
  memory {
    dedicated = "4096"
  }

  bios = "ovmf"

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = "16"
    iothread     = true
    discard      = "ignore"
  }

  machine = "q35"

  clone {
    vm_id = 109
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id     = "36"

  }
  lifecycle {
    ignore_changes = [
      clone,
      initialization
    ]
  }
}
