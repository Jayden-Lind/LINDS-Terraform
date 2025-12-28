resource "proxmox_virtual_environment_vm" "jd-plex-02" {
  name      = "JD-Plex-01"
  tags      = ["plex"]
  node_name = var.hostname
  agent {
    enabled = true
  }
  cpu {
    type         = "host"
    architecture = "x86_64"
    cores        = "4"
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
    numa = true
  }
  memory {
    dedicated = "4096"
  }

  bios = "ovmf"

  scsi_hardware = "virtio-scsi-single"

  startup {
    order      = "6"
    up_delay   = "60"
    down_delay = "60"
  }

  disk {
    datastore_id = var.datastore_jd
    interface    = "scsi0"
    size         = "16"
    iothread     = true
    discard      = "ignore"
  }

  machine = "q35"

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

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 53
    queues  = 4

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

resource "proxmox_virtual_environment_vm" "jd-torrent-01" {
  name      = "JD-Torrent-01"
  tags      = ["torrent"]
  node_name = var.hostname
  agent {
    enabled = true
  }
  cpu {
    type         = "host"
    cores        = "8"
    architecture = "x86_64"
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
    numa = true
  }
  memory {
    dedicated = "16384"
  }

  bios = "ovmf"

  startup {
    order      = "6"
    up_delay   = "60"
    down_delay = "60"
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = var.datastore_jd
    interface    = "scsi0"
    size         = "16"
    iothread     = true
    discard      = "ignore"
  }

  machine = "q35"

  clone {
    vm_id = 109
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = "0"
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

resource "proxmox_virtual_environment_vm" "talos_cp" {
  name      = "talos-cp-01"
  tags      = ["kubernetes", "control-plane", "talos"]
  node_name = var.hostname
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
      "-pdpe1gb",
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
    datastore_id = var.datastore_jd
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
    vlan_id     = "53"
    mac_address = "BC:24:11:D4:F3:C1"
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

locals {
  talos_worker_mac_addresses = [
    "02:24:11:d4:f3:d1",
    "02:24:11:d4:f3:d2",
    "02:24:11:d4:f3:d3",
  ]
}

resource "proxmox_virtual_environment_vm" "talos_worker" {
  count     = 3
  name      = "talos-worker-${format("%02d", count.index + 1)}"
  tags      = ["kubernetes", "worker", "talos"]
  node_name = var.hostname
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
      "-pdpe1gb",
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
    datastore_id = var.datastore_jd
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
    vlan_id     = "53"
    mac_address = local.talos_worker_mac_addresses[count.index]

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

resource "proxmox_virtual_environment_file" "kube_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.hostname
  source_raw {
    data      = <<EOF
#cloud-config
package_update: true
package_upgrade: true
packages:
  - qemu-guest-agent
EOF
    file_name = "kube.cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_network_linux_bridge" "LAN_Interface" {

  node_name = var.hostname
  name      = "vmbr0"

  address    = "10.0.50.246/24"
  gateway    = "10.0.50.1"
  vlan_aware = true
  comment    = "LAN"
  mtu        = 1500
  ports = [
    "ens5f1np1"
  ]
}

resource "proxmox_virtual_environment_network_linux_bridge" "WAN_Interface" {

  node_name = var.hostname
  name      = "vmbr1"

  comment = "WAN"

  ports = [
    "ens5f0np0"
  ]
}
