resource "proxmox_virtual_environment_vm" "linds-plex-02" {
  provider  = proxmox.linds
  name      = "LINDS-Plex-01"
  node_name = var.hostname_linds

  cpu {
    type         = "host"
    cores        = "4"
    architecture = "x86_64"
  }
  memory {
    dedicated = "8192"
  }

  bios = "ovmf"

  machine = "q35"

  scsi_hardware = "virtio-scsi-single"

  clone {
    vm_id = 150
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = "20"
    iothread     = true
    discard      = "ignore"
  }

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
  provider = proxmox.linds
  name     = "LINDS-Torrent-01"

  node_name = var.hostname_linds

  cpu {
    type         = "host"
    cores        = "4"
    architecture = "x86_64"
  }
  memory {
    dedicated = "8192"
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
    vlan_id = "36"

  }
  lifecycle {
    ignore_changes = [
      clone,
      initialization
    ]
  }
}

locals {
  linds_talos_worker_mac_addresses = [
    "02:24:11:d4:f3:e1",
    "02:24:11:d4:f3:e2",
  ]
}

resource "proxmox_virtual_environment_vm" "talos_worker_linds" {
  provider  = proxmox.linds
  count     = 2
  name      = "talos-linds-worker-${format("%02d", count.index + 1)}"
  tags      = ["kubernetes", "worker", "talos"]
  node_name = var.hostname_linds
  agent {
    enabled = true
  }
  cpu {
    type         = "host"
    architecture = "x86_64"
    cores        = 4
    flags = [
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
  memory {
    dedicated = 16384
  }

  bios       = "ovmf"
  boot_order = ["scsi0", "ide3"]

  startup {
    order      = "8"
    up_delay   = "60"
    down_delay = "60"
  }

  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = "75"
    iothread     = true
    discard      = "ignore"
  }

  machine = "q35"

  scsi_hardware = "virtio-scsi-single"

  cdrom {
    file_id = "local:iso/talos.iso"
  }

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    vlan_id     = "300"
    mac_address = local.linds_talos_worker_mac_addresses[count.index]

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