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
  cpu_flags      = local.talos_cpu_flags
  vlan_id        = 300
  network_queues = 4
  cdrom_file_id  = proxmox_virtual_environment_download_file.talos_iso_linds.id
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
    discard      = "on"
    ssd          = true
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
    discard      = "on"
    ssd          = true
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

###############################################################################
# LINDS-DC2 (112) - Windows domain controller, DNS
#
# Cloned from the Packer-built Windows Server template (../packer/windows).
# Terraform's part ends at a running guest with a random name and a DHCP
# address; LINDS-Ansible (playbooks/windows-build.yml) names it, addresses it,
# joins it to linds.com.au and promotes it.
#
# This replaces VM 110, which was built by hand: it had no OS type set, so it
# booted with its clock 10-11 hours slow after every cold start, and it had
# stopped being able to install cumulative updates.
###############################################################################

resource "proxmox_virtual_environment_vm" "linds_dc2" {
  provider  = proxmox.linds
  name      = "LINDS-DC2"
  vm_id     = 112
  node_name = local.nodes.linds.name

  # The template carries the QEMU guest agent, and outputs.tf reads the
  # guest's DHCP address through it.
  agent {
    enabled = true
  }

  cpu {
    type         = "host"
    architecture = "x86_64"
    cores        = 4
  }

  memory {
    dedicated = 8192
    floating  = 0 # ballooning off
  }

  bios = "ovmf"
  # Pinned, as the template is: Windows notices when its chipset version moves.
  machine = "pc-q35-11.0+pve2"
  on_boot = true

  # A domain controller. Attribute writes must never restart it behind your
  # back.
  reboot_after_update = false

  boot_order    = ["scsi0"]
  scsi_hardware = "virtio-scsi-single"

  # Not cosmetic: a Windows OS type is what makes Proxmox give the guest a
  # hardware clock in local time. Without it Windows reads a UTC clock as
  # local time and comes up hours out, which breaks Kerberos until the time
  # service steps it.
  operating_system {
    type = "win11"
  }

  startup {
    order    = "10"
    up_delay = "30"
  }

  clone {
    vm_id = local.windows_template_vm_id
  }

  # Matches the template: a real EFI variable store with Secure Boot on.
  efi_disk {
    datastore_id      = local.datastores.linds
    type              = "4m"
    pre_enrolled_keys = true
  }

  # The template's disk is 60 GB; the clone is grown to this and Windows
  # extends C: into it on first boot.
  disk {
    datastore_id = local.datastores.linds
    interface    = "scsi0"
    size         = 100
    cache        = "none"
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 300
  }

  lifecycle {
    # The clone source is only read at create time.
    ignore_changes = [clone]
  }
}

# LINDS-DC rebuilt from the Windows template: domain controller, the CA and
# the LINDS file server. Replaces VM 102 (LINDS-DC-01, built by hand), which
# is kept switched off as the owner of the NAS disk. The order of the swap is
# in LINDS-Ansible, docs/windows-domain.md, "replacing a domain controller".
resource "proxmox_virtual_environment_vm" "linds_dc" {
  provider  = proxmox.linds
  name      = "LINDS-DC"
  vm_id     = 113
  node_name = local.nodes.linds.name

  # The template carries the QEMU guest agent, and outputs.tf reads the
  # guest's DHCP address through it.
  agent {
    enabled = true
  }

  cpu {
    type         = "host"
    architecture = "x86_64"
    cores        = 8
  }

  memory {
    dedicated = 16384
    floating  = 0 # ballooning off
  }

  bios = "ovmf"
  # Pinned, as the template is: Windows notices when its chipset version moves.
  machine = "pc-q35-11.0+pve2"
  on_boot = true

  # A domain controller. Attribute writes must never restart it behind your
  # back.
  reboot_after_update = false

  boot_order    = ["scsi0"]
  scsi_hardware = "virtio-scsi-single"

  # Not cosmetic: a Windows OS type is what makes Proxmox give the guest a
  # hardware clock in local time. Without it Windows reads a UTC clock as
  # local time and comes up hours out, which breaks Kerberos until the time
  # service steps it.
  operating_system {
    type = "win11"
  }

  startup {
    order    = "10"
    up_delay = "30"
  }

  clone {
    vm_id = local.windows_template_vm_id
  }

  # Matches the template: a real EFI variable store with Secure Boot on.
  efi_disk {
    datastore_id      = local.datastores.linds
    type              = "4m"
    pre_enrolled_keys = true
  }

  # The template's disk is 60 GB; the clone is grown to this and Windows
  # extends C: into it on first boot.
  disk {
    datastore_id = local.datastores.linds
    interface    = "scsi0"
    size         = 100
    cache        = "none"
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 300
  }

  # The NAS data disk is not in this resource, on purpose. It belongs to the
  # old VM 102 (NAS:vm-102-disk-0), which stays as a switched-off shell, and is
  # attached to this VM by reference with LINDS-Ansible's
  # playbooks/windows-data-disk.yml, the way the LINDS-Backup VM already
  # attaches it. Proxmox only deletes volumes that carry the ID of the VM
  # being destroyed, so replacing or destroying this VM cannot touch it
  # (tried on a dummy disk, 2026-10-12). `disk` is ignored so that Terraform
  # neither detaches it nor tries to resize an 11 TB volume to a round number.
  lifecycle {
    # The clone source is only read at create time.
    ignore_changes = [clone, disk]
  }
}
