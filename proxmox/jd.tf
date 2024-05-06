variable "kubernetes" {
  type = list(object({
    name  = string
    cores = string
    ram   = number
  }))

  default = [
    {
      name  = "jd-kube-01"
      cores = "4"
      ram   = 8192
    },
    {
      name  = "jd-kube-02"
      cores = "4"
      ram   = 16384
    },
    {
      name  = "jd-kube-03"
      cores = "4"
      ram   = 16384
    },
  ]
}

variable "datastore" {
  default = "local-lvm"
}

variable "hostname" {
  default = "jd-proxmox-01"
}

resource "proxmox_virtual_environment_vm" "kubernetes_nodes" {
  count      = length(var.kubernetes)
  depends_on = [proxmox_virtual_environment_file.kube_cloud_config]
  name       = var.kubernetes[count.index].name
  tags       = ["kubernetes"]
  node_name  = var.hostname
  agent {
    enabled = true
  }
  cpu {
    type  = "host"
    cores = var.kubernetes[count.index].cores
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
    dedicated = var.kubernetes[count.index].ram
  }

  bios = "ovmf"

  startup {
    order      = "8"
    up_delay   = "60"
    down_delay = "60"
  }

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

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    #    user_data_file_id = proxmox_virtual_environment_file.kube_cloud_config.id
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = "53"
  }

  operating_system {
    type = "l26"
  }
}

resource "proxmox_virtual_environment_vm" "jd-plex-01" {
  name       = "JD-Plex-01"
  tags       = ["plex"]
  node_name  = var.hostname
  agent {
    enabled = true
  }
  cpu {
    type  = "host"
    cores = "4"
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
    dedicated = "4096"
  }

  bios = "ovmf"

  startup {
    order      = "6"
    up_delay   = "60"
    down_delay = "60"
  }

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

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    #    user_data_file_id = proxmox_virtual_environment_file.kube_cloud_config.id
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"

  }

  operating_system {
    type = "l26"
  }
}

resource "proxmox_virtual_environment_vm" "jd-torrent-01" {
  name       = "JD-Torrent-01"
  tags       = ["torrent"]
  node_name  = var.hostname
  agent {
    enabled = true
  }
  cpu {
    type  = "host"
    cores = "8"
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
    dedicated = "16384"
  }

  bios = "ovmf"

  startup {
    order      = "6"
    up_delay   = "60"
    down_delay = "60"
  }

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
    vlan_id = "51"
  }

  operating_system {
    type = "l26"
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

  address    = "10.0.50.245/24"
  gateway    = "10.0.50.1"
  vlan_aware = true
  comment    = "Main LAN"

  ports = [
    "ens1f0np0"
  ]
}

resource "proxmox_virtual_environment_network_linux_bridge" "WAN_Interface" {

  node_name = var.hostname
  name      = "vmbr1"

  comment = "WAN Port"

  ports = [
    "ens1f1np1"
  ]
}