###############################################################################
# Talos cluster nodes - JD site (jd-proxmox-02)
#
# Nodes get their addresses from DHCP reservations keyed on the MACs below:
#   talos-cp-01     10.0.53.200
#   talos-worker-01 10.0.53.201
#   talos-worker-02 10.0.53.202
#   talos-worker-03 10.0.53.203
###############################################################################

module "talos_cp_jd" {
  source = "./modules/talos-node"

  nodes = {
    "talos-cp-01" = { mac_address = "BC:24:11:D4:F3:C1" }
  }

  role           = "controlplane"
  node_name      = local.nodes.jd.name
  datastore_id   = local.datastores.jd
  cores          = 8
  memory         = 16384
  cpu_flags      = local.guest_cpu_flags
  vlan_id        = 53
  network_queues = 8
}

module "talos_workers_jd" {
  source = "./modules/talos-node"

  nodes = {
    "talos-worker-01" = { mac_address = "02:24:11:d4:f3:d1" }
    "talos-worker-02" = { mac_address = "02:24:11:d4:f3:d2" }
    "talos-worker-03" = { mac_address = "02:24:11:d4:f3:d3" }
  }

  role           = "worker"
  node_name      = local.nodes.jd.name
  datastore_id   = local.datastores.jd
  cores          = 8
  memory         = 16384
  cpu_flags      = local.guest_cpu_flags
  vlan_id        = 53
  network_queues = 8
}

###############################################################################
# JD-VyOS-01 (1100) - site router - DELIBERATELY NOT MANAGED HERE
#
# Adopting this VM went wrong, and the reason is structural rather than a
# tuning problem: the router has a NIC at net1 and nothing at net0, and the
# provider models network devices as a dense list. The empty index 0 in state
# got materialised into a real `net0: virtio=BC:24:11:BF:02:70` on the host.
#
# `enabled = false` does not prevent this - the provider deprecated that
# attribute precisely because it no longer suppresses the device - and
# `ignore_changes` does not help either, because it makes the *state* value
# authoritative and the state is what carries the empty slot.
#
# This VM terminates the IPsec tunnel to LINDS, is BGP peer 64550, and holds an
# SR-IOV VF for its WAN leg. It is not worth risking to save a `qm` command, so
# it is managed by hand. See removed.tf.
#
# To bring it back under Terraform, renumber its NIC to net0 inside VyOS during
# a maintenance window - then the list is dense and the model is honest. The
# resource definition is preserved in git history if you want it back.
###############################################################################

###############################################################################
# JD-DC-01 (1102) - Windows domain controller / file server
#
# scsi1 is the 14.2 TiB zvol on the NAS-SSD raidz1 that holds the bulk file
# shares. Destroying this VM would take that zvol with it.
###############################################################################

resource "proxmox_virtual_environment_vm" "jd_dc" {
  name      = "JD-DC-01"
  vm_id     = 1102
  node_name = local.nodes.jd.name

  agent {
    enabled = true
  }

  cpu {
    type         = "host"
    architecture = "x86_64"
    cores        = 8
    numa         = true
    # As local.guest_cpu_flags, plus -nested-virt: no Hyper-V / WSL2 in here,
    # and disabling it lets the guest run without the nested-paging tax.
    flags = concat(["-nested-virt"], local.guest_cpu_flags)
  }

  memory {
    dedicated = 32784
    floating  = 0 # ballooning off
  }

  bios    = "ovmf"
  machine = "pc-q35-10.1"
  on_boot = true

  # Domain controller and file server. Same reasoning as JD-VyOS-01: attribute
  # writes must never trigger a restart behind your back.
  reboot_after_update = false

  boot_order    = ["scsi0"]
  scsi_hardware = "virtio-scsi-single"

  startup {
    order    = "2"
    up_delay = "100"
  }

  disk {
    datastore_id = local.datastores.jd
    interface    = "scsi0"
    size         = 40
    cache        = "writeback"
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  disk {
    datastore_id = "NAS-SSD"
    interface    = "scsi1"
    size         = 14549
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    mac_address = "BC:24:11:6E:FE:3F"
    queues      = 8
  }

  operating_system {
    type = "win11"
  }

  lifecycle {
    prevent_destroy = true
  }
}

###############################################################################
# JD-Minecraft-01 (1110) - stopped
#
# Predates the rest of the fleet: still on SeaBIOS/i440fx with the LSI SCSI
# controller and no NIC, and it carries an orphaned `unused0` volume on
# local-lvm that Terraform does not model. See README for the cleanup notes.
###############################################################################

resource "proxmox_virtual_environment_vm" "jd_minecraft" {
  name      = "JD-Minecraft-01"
  vm_id     = 1110
  node_name = local.nodes.jd.name

  started = false
  on_boot = false

  cpu {
    cores = 8
  }

  memory {
    dedicated = 32768
  }

  boot_order = ["scsi0"]

  # No scsihw line on the host, i.e. the PVE default. Pinned explicitly so
  # Terraform does not "helpfully" move it to virtio-scsi-pci, which the
  # installed guest was not built against.
  scsi_hardware = "lsi"

  disk {
    datastore_id = local.datastores.jd
    interface    = "scsi0"
    size         = 50
  }

  lifecycle {
    prevent_destroy = true
  }
}

###############################################################################
# JD-Dev-02 (1111) - stopped scratch VM on VLAN 58
###############################################################################

resource "proxmox_virtual_environment_vm" "jd_dev" {
  name      = "JD-Dev-02"
  vm_id     = 1111
  node_name = local.nodes.jd.name

  started = false
  on_boot = false

  cpu {
    type         = "host"
    architecture = "x86_64"
    cores        = 4
  }

  memory {
    dedicated = 16384
  }

  bios       = "ovmf"
  machine    = "q35"
  boot_order = ["scsi0"]

  scsi_hardware = "virtio-scsi-pci"

  disk {
    datastore_id = local.datastores.jd
    interface    = "scsi0"
    size         = 50
  }

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    mac_address = "BC:24:11:51:74:1A"
    vlan_id     = 58
    firewall    = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

###############################################################################
# JD-Torrent-01 (104) - cloned from the packer Ubuntu LTS template
###############################################################################

resource "proxmox_virtual_environment_vm" "jd_torrent" {
  name      = "JD-Torrent-01"
  tags      = ["torrent"]
  node_name = local.nodes.jd.name

  agent {
    enabled = true
  }

  cpu {
    type         = "host"
    architecture = "x86_64"
    cores        = 8
    flags        = local.guest_cpu_flags
    numa         = true
  }

  memory {
    dedicated = 16384
  }

  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"

  startup {
    order      = "6"
    up_delay   = "60"
    down_delay = "60"
  }

  disk {
    datastore_id = local.datastores.jd
    interface    = "scsi0"
    size         = 16
    iothread     = true
    discard      = "ignore"
  }

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

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 0
    queues  = 8
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = [clone]
  }
}

###############################################################################
# Cloud-init snippet used by cloned guests
###############################################################################

resource "proxmox_virtual_environment_file" "kube_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = local.nodes.jd.name

  source_raw {
    data      = <<-EOF
      #cloud-config
      package_update: true
      package_upgrade: true
      packages:
        - qemu-guest-agent
    EOF
    file_name = "kube.cloud-config.yaml"
  }
}
