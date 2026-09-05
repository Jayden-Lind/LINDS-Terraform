resource "proxmox_virtual_environment_vm" "this" {
  for_each = var.nodes

  name      = each.key
  node_name = var.node_name
  tags      = sort(["kubernetes", "talos", var.role == "controlplane" ? "control-plane" : "worker"])

  agent {
    enabled = true
  }

  cpu {
    type         = "host"
    architecture = "x86_64"
    cores        = var.cores
    flags        = var.cpu_flags
  }

  memory {
    dedicated = var.memory
  }

  bios       = "ovmf"
  machine    = "q35"
  boot_order = ["scsi0", "ide3"]

  scsi_hardware = "virtio-scsi-single"

  startup {
    order      = tostring(var.startup_order)
    up_delay   = "60"
    down_delay = "60"
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  cdrom {
    file_id = var.cdrom_file_id
  }

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    vlan_id     = var.vlan_id
    mac_address = each.value.mac_address
    queues      = var.network_queues
  }

  operating_system {
    type = "l26"
  }

  # Never let a Terraform apply reboot a cluster node as a side effect of a
  # VM attribute change (bpg defaults this to true). Reboots are done with
  # talosctl, one node at a time, after cordon and drain.
  reboot_after_update = false

  lifecycle {
    ignore_changes = [clone]
  }
}
