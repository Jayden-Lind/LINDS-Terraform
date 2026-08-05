###############################################################################
# LINDS site (linds-proxmox-01, 192.168.6.205)
#
# Second site, joined to the JD site over an IPsec tunnel between the two VyOS
# routers. Talos workers here get 10.3.1.100-101 and are labelled
# datacenter=linds so Cilium peers them with the LINDS router (ASN 64513).
#
# NOTE: this host is currently out of scope for reconciliation work - only the
# guests below are managed, not its storage or networking.
###############################################################################

module "talos_workers_linds" {
  source = "./modules/talos-node"

  providers = {
    proxmox = proxmox.linds
  }

  nodes = {
    "talos-linds-worker-01" = { mac_address = "02:24:11:d4:f3:e1" }
    "talos-linds-worker-02" = { mac_address = "02:24:11:d4:f3:e2" }
  }

  role           = "worker"
  node_name      = local.nodes.linds.name
  datastore_id   = local.datastores.linds
  cores          = 4
  memory         = 16384
  cpu_flags      = local.guest_cpu_flags
  vlan_id        = 300
  network_queues = 4
}

resource "proxmox_virtual_environment_vm" "linds_plex" {
  provider  = proxmox.linds
  name      = "LINDS-Plex-01"
  node_name = local.nodes.linds.name

  cpu {
    type         = "host"
    architecture = "x86_64"
    cores        = 4
  }

  memory {
    dedicated = 8192
  }

  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"

  clone {
    vm_id = local.ubuntu_template_vm_id
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  disk {
    datastore_id = local.datastores.linds
    interface    = "scsi0"
    size         = 20
    iothread     = true
    discard      = "ignore"
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 300
  }

  lifecycle {
    ignore_changes = [clone]
  }
}

resource "proxmox_virtual_environment_vm" "linds_torrent" {
  provider  = proxmox.linds
  name      = "LINDS-Torrent-02"
  node_name = local.nodes.linds.name

  cpu {
    type         = "host"
    architecture = "x86_64"
    cores        = 4
  }

  memory {
    dedicated = 8192
  }

  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = local.datastores.linds
    interface    = "scsi0"
    size         = 16
    iothread     = true
    discard      = "ignore"
  }

  clone {
    vm_id = 151
  }

  initialization {
    ip_config {
      ipv4 {
        address = "10.0.36.2/24"
        gateway = "10.0.36.1"
      }
    }
  }

  startup {
    order      = "10"
    up_delay   = "60"
    down_delay = "60"
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 36
  }

  lifecycle {
    ignore_changes = [
      clone,
      initialization,
    ]
  }
}
