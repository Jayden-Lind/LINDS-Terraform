###############################################################################
# Guests made by hand or by Packer, adopted on 2026-11-07 (imports.tf)
#
# The attributes are what Proxmox reported at the import (terraform plan
# -generate-config-out), so the import changed nothing. Each one has
# prevent_destroy and reboot_after_update = false. Packer owns the templates
# and rebuilds them: Terraform records them and ignores their changes.
###############################################################################

# Ubuntu 26.04 template (150), built by Packer.
resource "proxmox_virtual_environment_vm" "jd_ubuntu_template" {
  acpi                                 = true
  bios                                 = "ovmf"
  boot_order                           = ["scsi0", "net0"]
  delete_unreferenced_disks_on_destroy = true
  description                          = "Ubuntu 26.04 LTS, built by Packer"
  keyboard_layout                      = "en-us"
  mac_addresses                        = ["7A:5B:63:9F:6F:DD"]
  machine                              = "q35"
  migrate                              = false
  name                                 = "ubuntu"
  network_device = [{
    bridge       = "vmbr0"
    disconnected = false
    enabled      = true
    firewall     = false
    mac_address  = "7A:5B:63:9F:6F:DD"
    model        = "virtio"
    mtu          = 0
    queues       = 0
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 0
  }]
  node_name           = "jd-proxmox-02"
  on_boot             = false
  protection          = false
  purge_on_destroy    = true
  reboot              = false
  reboot_after_update = false
  scsi_hardware       = "virtio-scsi-single"
  started             = false
  stop_on_destroy     = false
  tablet_device       = true
  tags                = []
  template            = true
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_migrate     = 1800
  timeout_reboot      = 1800
  timeout_shutdown_vm = 1800
  timeout_start_vm    = 1800
  timeout_stop_vm     = 300
  vm_id               = 150
  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }
  cpu {
    cores      = 4
    flags      = []
    hotplugged = 0
    limit      = 0
    numa       = false
    sockets    = 1
    type       = "host"
  }
  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "local-lvm"
    discard           = "ignore"
    file_format       = "raw"
    interface         = "scsi0"
    iothread          = true
    path_in_datastore = "base-150-disk-0"
    queues            = 0
    replicate         = false
    size              = 16
    ssd               = false
  }
  memory {
    dedicated      = 4096
    floating       = 0
    keep_hugepages = false
    shared         = 0
  }
  operating_system {
    type = "l26"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

# Windows Server 2025 template (160), built by Packer (../packer/windows).
# Clone source for the Windows VMs at JD (local.windows_template_vm_id).
resource "proxmox_virtual_environment_vm" "jd_windows_template" {
  acpi                                 = true
  bios                                 = "ovmf"
  boot_order                           = ["scsi0", "net0"]
  delete_unreferenced_disks_on_destroy = true
  description                          = "Windows Server 2025 Standard Evaluation (Desktop Experience), built by Packer"
  keyboard_layout                      = "en-us"
  mac_addresses                        = ["4E:5B:AC:43:4D:23"]
  machine                              = "pc-q35-11.0+pve2"
  migrate                              = false
  name                                 = "windows-server-2025"
  network_device = [{
    bridge       = "vmbr0"
    disconnected = false
    enabled      = true
    firewall     = false
    mac_address  = "4E:5B:AC:43:4D:23"
    model        = "virtio"
    mtu          = 0
    queues       = 0
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 0
  }]
  node_name           = "jd-proxmox-02"
  on_boot             = false
  protection          = false
  purge_on_destroy    = true
  reboot              = false
  reboot_after_update = false
  scsi_hardware       = "virtio-scsi-single"
  started             = false
  stop_on_destroy     = false
  tablet_device       = true
  tags                = []
  template            = true
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_migrate     = 1800
  timeout_reboot      = 1800
  timeout_shutdown_vm = 1800
  timeout_start_vm    = 1800
  timeout_stop_vm     = 300
  vm_id               = 160
  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }
  cpu {
    cores      = 4
    flags      = []
    hotplugged = 0
    limit      = 0
    numa       = false
    sockets    = 1
    type       = "host"
  }
  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "ssd-mixed"
    discard           = "on"
    file_format       = "raw"
    interface         = "scsi0"
    iothread          = true
    path_in_datastore = "base-160-disk-1"
    queues            = 0
    replicate         = false
    size              = 60
    ssd               = true
  }
  efi_disk {
    datastore_id      = "ssd-mixed"
    file_format       = "raw"
    pre_enrolled_keys = true
    type              = "4m"
  }
  memory {
    dedicated      = 8192
    floating       = 0
    keep_hugepages = false
    shared         = 0
  }
  operating_system {
    type = "win11"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

# JD-Backup-01 (1115): Backblaze Personal for the NAS. LINDS-Ansible
# roles/backblaze starts it once a week (backblaze-run.timer), attaches a ZFS
# clone of jd-fs-01's D: as a disk, and shuts it down after the run. The
# disks and the power state change on their own, so both are ignored.
resource "proxmox_virtual_environment_vm" "jd_backup" {
  acpi                                 = true
  bios                                 = "ovmf"
  boot_order                           = ["scsi0"]
  delete_unreferenced_disks_on_destroy = true
  description                          = "Backblaze Personal Backup of the NAS (LINDS-Ansible roles/backblaze). Moved from linds-proxmox-01 VM 104 (LINDS-Backup) on 2026-11-04. backblaze-run.timer starts it once a week with a ZFS clone of jd-fs-01 D: as scsi1. Never attach the live NAS-SSD:vm-1113-disk-0."
  keyboard_layout                      = "en-us"
  mac_addresses                        = ["BC:24:11:0A:ED:0C"]
  machine                              = "pc-q35-8.1"
  migrate                              = false
  name                                 = "JD-Backup-01"
  network_device = [{
    bridge       = "vmbr0"
    disconnected = false
    enabled      = true
    firewall     = false
    mac_address  = "BC:24:11:0A:ED:0C"
    model        = "virtio"
    mtu          = 0
    queues       = 4
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 0
  }]
  node_name           = "jd-proxmox-02"
  on_boot             = false
  protection          = false
  purge_on_destroy    = true
  reboot              = false
  reboot_after_update = false
  scsi_hardware       = "virtio-scsi-single"
  started             = false
  stop_on_destroy     = false
  tablet_device       = true
  tags                = []
  template            = false
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_migrate     = 1800
  timeout_reboot      = 1800
  timeout_shutdown_vm = 1800
  timeout_start_vm    = 1800
  timeout_stop_vm     = 300
  vm_id               = 1115
  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }
  cpu {
    cores      = 8
    flags      = []
    hotplugged = 0
    limit      = 0
    numa       = false
    sockets    = 1
    type       = "host"
  }
  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "ssd-mixed"
    discard           = "on"
    file_format       = "raw"
    interface         = "scsi0"
    iothread          = false
    path_in_datastore = "vm-1115-disk-0"
    queues            = 0
    replicate         = true
    size              = 40
    ssd               = true
  }
  efi_disk {
    datastore_id      = "ssd-mixed"
    file_format       = "raw"
    pre_enrolled_keys = true
    type              = "4m"
  }
  memory {
    dedicated      = 32768
    floating       = 0
    keep_hugepages = false
    shared         = 0
  }
  operating_system {
    type = "win10"
  }
  tpm_state {
    datastore_id = "ssd-mixed"
    version      = "v2.0"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [disk, started]
  }
}

# LINDS-Truenas-01 (103): the LINDS NAS (TrueNAS, 12 TB disk on the TrueNAS
# pool). Proxmox has no OS type for it, and the provider would write "other".
resource "proxmox_virtual_environment_vm" "linds_truenas" {
  provider                             = proxmox.linds
  acpi                                 = true
  bios                                 = "ovmf"
  boot_order                           = ["scsi0"]
  delete_unreferenced_disks_on_destroy = true
  keyboard_layout                      = "en-us"
  mac_addresses                        = ["BC:24:11:A0:0E:76"]
  machine                              = "q35"
  migrate                              = false
  name                                 = "LINDS-Truenas-01"
  network_device = [{
    bridge       = "vmbr0"
    disconnected = false
    enabled      = true
    firewall     = false
    mac_address  = "BC:24:11:A0:0E:76"
    model        = "virtio"
    mtu          = 0
    queues       = 4
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 300
  }]
  node_name           = "linds-proxmox-01"
  on_boot             = true
  protection          = false
  purge_on_destroy    = true
  reboot              = false
  reboot_after_update = false
  scsi_hardware       = "virtio-scsi-single"
  started             = true
  stop_on_destroy     = false
  tablet_device       = true
  tags                = []
  template            = false
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_migrate     = 1800
  timeout_reboot      = 1800
  timeout_shutdown_vm = 1800
  timeout_start_vm    = 1800
  timeout_stop_vm     = 300
  vm_id               = 103
  cpu {
    cores      = 4
    flags      = []
    hotplugged = 0
    limit      = 0
    numa       = false
    sockets    = 1
    type       = "host"
  }
  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "local-lvm"
    discard           = "on"
    file_format       = "raw"
    interface         = "scsi0"
    iothread          = true
    path_in_datastore = "vm-103-disk-0"
    queues            = 0
    replicate         = true
    size              = 16
    ssd               = true
  }
  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "local-lvm"
    discard           = "on"
    file_format       = "raw"
    interface         = "scsi1"
    iothread          = true
    path_in_datastore = "vm-103-disk-1"
    queues            = 0
    replicate         = true
    size              = 200
    ssd               = true
  }
  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "TrueNAS"
    discard           = "on"
    file_format       = "raw"
    interface         = "scsi2"
    iothread          = true
    path_in_datastore = "vm-103-disk-0"
    queues            = 0
    replicate         = true
    size              = 12000
    ssd               = false
  }
  memory {
    dedicated      = 16384
    floating       = 0
    keep_hugepages = false
    shared         = 0
  }
  operating_system {
  }
  startup {
    down_delay = -1
    order      = 2
    up_delay   = 10
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [operating_system]
  }
}

# LINDS-DC-old (102): a switched-off shell, kept because it OWNS
# NAS:vm-102-disk-0, the data disk that LINDS-DC (113) uses (see linds_dc).
# Destroying this VM deletes that disk. Never start it, never destroy it.
resource "proxmox_virtual_environment_vm" "linds_dc_old" {
  provider                             = proxmox.linds
  acpi                                 = true
  bios                                 = "ovmf"
  boot_order                           = ["scsi0", "scsi1", "sata0"]
  delete_unreferenced_disks_on_destroy = true
  keyboard_layout                      = "en-us"
  mac_addresses                        = ["BC:24:11:A0:0E:77"]
  machine                              = "pc-q35-10.1"
  migrate                              = false
  name                                 = "LINDS-DC-old"
  network_device = [{
    bridge       = "vmbr0"
    disconnected = false
    enabled      = true
    firewall     = false
    mac_address  = "BC:24:11:A0:0E:77"
    model        = "virtio"
    mtu          = 0
    queues       = 4
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 300
  }]
  node_name           = "linds-proxmox-01"
  on_boot             = false
  protection          = true
  purge_on_destroy    = true
  reboot              = false
  reboot_after_update = false
  scsi_hardware       = "virtio-scsi-pci"
  started             = false
  stop_on_destroy     = false
  tablet_device       = true
  tags                = []
  template            = false
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_migrate     = 1800
  timeout_reboot      = 1800
  timeout_shutdown_vm = 1800
  timeout_start_vm    = 1800
  timeout_stop_vm     = 300
  vm_id               = 102
  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }
  cdrom {
    file_id   = "cdrom"
    interface = "sata0"
  }
  cpu {
    cores      = 8
    flags      = ["-nested-virt", "-md-clear", "-pcid", "-spec-ctrl", "-ssbd", "-virt-ssbd", "-amd-ssbd", "-amd-no-ssb", "+pdpe1gb", "-hv-tlbflush", "-hv-evmcs", "+aes"]
    hotplugged = 0
    limit      = 0
    numa       = false
    sockets    = 1
    type       = "host"
  }
  disk {
    aio               = "io_uring"
    backup            = false
    cache             = "none"
    datastore_id      = "local-lvm"
    discard           = "on"
    file_format       = "raw"
    interface         = "scsi0"
    iothread          = false
    path_in_datastore = "vm-102-disk-0"
    queues            = 0
    replicate         = true
    size              = 100
    ssd               = true
  }
  disk {
    aio               = "io_uring"
    backup            = false
    cache             = "none"
    datastore_id      = "NAS"
    discard           = "on"
    file_format       = "raw"
    interface         = "scsi1"
    iothread          = false
    path_in_datastore = "vm-102-disk-0"
    queues            = 0
    replicate         = true
    size              = 11171
    ssd               = false
  }
  memory {
    dedicated      = 16384
    floating       = 0
    keep_hugepages = false
    shared         = 0
  }
  operating_system {
    type = "win11"
  }
  startup {
    down_delay = -1
    order      = 2
    up_delay   = 180
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [disk]
  }
}

# LINDS-Backup-old (104): the old Backblaze VM, switched off as the fallback
# for JD-Backup-01. It has LINDS-DC's NAS disk (owned by 102) attached.
resource "proxmox_virtual_environment_vm" "linds_backup_old" {
  provider                             = proxmox.linds
  acpi                                 = true
  bios                                 = "ovmf"
  boot_order                           = ["scsi0"]
  delete_unreferenced_disks_on_destroy = true
  description                          = "OLD Backblaze VM, kept switched off as a fallback. Since 2026-11-06 the Backblaze runs are on jd-proxmox-02 (VM 1115 JD-Backup-01, ZFS clone of jd-fs-01 D:, LINDS-Ansible roles/backblaze). scsi1 is NAS:vm-102-disk-0, the live disk of linds-dc (VM 113): never start this VM while 113 runs. Delete it when Jayden says."
  keyboard_layout                      = "en-us"
  mac_addresses                        = ["BC:24:11:0A:ED:0C"]
  machine                              = "pc-q35-8.1"
  migrate                              = false
  name                                 = "LINDS-Backup-old"
  network_device = [{
    bridge       = "vmbr0"
    disconnected = false
    enabled      = true
    firewall     = false
    mac_address  = "BC:24:11:0A:ED:0C"
    model        = "virtio"
    mtu          = 0
    queues       = 4
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 300
  }]
  node_name           = "linds-proxmox-01"
  on_boot             = false
  protection          = false
  purge_on_destroy    = true
  reboot              = false
  reboot_after_update = false
  scsi_hardware       = "virtio-scsi-single"
  started             = false
  stop_on_destroy     = false
  tablet_device       = true
  tags                = []
  template            = false
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_migrate     = 1800
  timeout_reboot      = 1800
  timeout_shutdown_vm = 1800
  timeout_start_vm    = 1800
  timeout_stop_vm     = 300
  vm_id               = 104
  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }
  cpu {
    cores      = 4
    flags      = []
    hotplugged = 0
    limit      = 0
    numa       = false
    sockets    = 1
    type       = "host"
  }
  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "local-lvm"
    discard           = "on"
    file_format       = "raw"
    interface         = "scsi0"
    iothread          = false
    path_in_datastore = "vm-104-disk-0"
    queues            = 0
    replicate         = true
    size              = 40
    ssd               = true
  }
  disk {
    aio               = "io_uring"
    backup            = false
    cache             = "writeback"
    datastore_id      = "NAS"
    discard           = "on"
    file_format       = "raw"
    interface         = "scsi1"
    iothread          = false
    path_in_datastore = "vm-102-disk-0"
    queues            = 0
    replicate         = true
    size              = 11171
    ssd               = false
  }
  efi_disk {
    datastore_id      = "local-lvm"
    file_format       = "raw"
    pre_enrolled_keys = true
    type              = "4m"
  }
  memory {
    dedicated      = 16384
    floating       = 0
    keep_hugepages = false
    shared         = 0
  }
  operating_system {
    type = "win10"
  }
  tpm_state {
    datastore_id = "local-lvm"
    version      = "v2.0"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [disk, started]
  }
}

# LINDS-DC2-old (110): the DC that LINDS-DC2 (112) replaced, switched off.
# Proxmox has no OS type for it, and the provider would write "other".
resource "proxmox_virtual_environment_vm" "linds_dc2_old" {
  provider                             = proxmox.linds
  acpi                                 = true
  bios                                 = "ovmf"
  boot_order                           = ["scsi0"]
  delete_unreferenced_disks_on_destroy = true
  keyboard_layout                      = "en-us"
  mac_addresses                        = ["BC:24:11:CE:01:4C"]
  machine                              = "q35"
  migrate                              = false
  name                                 = "LINDS-DC2-old"
  network_device = [{
    bridge       = "vmbr0"
    disconnected = false
    enabled      = true
    firewall     = false
    mac_address  = "BC:24:11:CE:01:4C"
    model        = "virtio"
    mtu          = 0
    queues       = 0
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 300
  }]
  node_name           = "linds-proxmox-01"
  on_boot             = false
  protection          = false
  purge_on_destroy    = true
  reboot              = false
  reboot_after_update = false
  scsi_hardware       = "virtio-scsi-pci"
  started             = false
  stop_on_destroy     = false
  tablet_device       = true
  tags                = []
  template            = false
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_migrate     = 1800
  timeout_reboot      = 1800
  timeout_shutdown_vm = 1800
  timeout_start_vm    = 1800
  timeout_stop_vm     = 300
  vm_id               = 110
  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }
  cpu {
    cores      = 4
    flags      = ["+aes"]
    hotplugged = 0
    limit      = 0
    numa       = false
    sockets    = 1
    type       = "host"
  }
  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "local-lvm"
    discard           = "on"
    file_format       = "raw"
    interface         = "scsi0"
    iothread          = false
    path_in_datastore = "vm-110-disk-0"
    queues            = 0
    replicate         = true
    size              = 100
    ssd               = true
  }
  memory {
    dedicated      = 8192
    floating       = 0
    keep_hugepages = false
    shared         = 0
  }
  operating_system {
  }
  startup {
    down_delay = -1
    order      = 10
    up_delay   = 30
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [operating_system]
  }
}

# CentOS 9 template (109), built by Packer.
resource "proxmox_virtual_environment_vm" "linds_centos_template" {
  provider                             = proxmox.linds
  acpi                                 = true
  bios                                 = "ovmf"
  boot_order                           = ["scsi0", "ide2", "net0"]
  delete_unreferenced_disks_on_destroy = true
  description                          = "packer generated centos-9"
  keyboard_layout                      = "en-us"
  mac_addresses                        = ["E6:E1:07:48:B7:1E"]
  machine                              = "q35"
  migrate                              = false
  name                                 = "centos-9"
  network_device = [{
    bridge       = "vmbr0"
    disconnected = false
    enabled      = true
    firewall     = true
    mac_address  = "E6:E1:07:48:B7:1E"
    model        = "virtio"
    mtu          = 0
    queues       = 0
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 300
  }]
  node_name           = "linds-proxmox-01"
  on_boot             = false
  protection          = false
  purge_on_destroy    = true
  reboot              = false
  reboot_after_update = false
  scsi_hardware       = "virtio-scsi-single"
  started             = false
  stop_on_destroy     = false
  tablet_device       = true
  tags                = []
  template            = true
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_migrate     = 1800
  timeout_reboot      = 1800
  timeout_shutdown_vm = 1800
  timeout_start_vm    = 1800
  timeout_stop_vm     = 300
  vm_id               = 109
  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }
  cdrom {
    file_id   = "none"
    interface = "ide2"
  }
  cpu {
    cores      = 4
    flags      = []
    hotplugged = 0
    limit      = 0
    numa       = false
    sockets    = 1
    type       = "host"
  }
  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "local-lvm"
    discard           = "on"
    file_format       = "raw"
    interface         = "scsi0"
    iothread          = true
    path_in_datastore = "base-109-disk-0"
    queues            = 0
    replicate         = true
    size              = 16
    ssd               = true
  }
  initialization {
    datastore_id = "local-lvm"
    interface    = "ide0"
    upgrade      = true
  }
  memory {
    dedicated      = 4096
    floating       = 0
    keep_hugepages = false
    shared         = 0
  }
  operating_system {
    type = "l26"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

# Ubuntu template (150), built by Packer. Clone source for LINDS-Plex-01
# (local.ubuntu_template_vm_id).
resource "proxmox_virtual_environment_vm" "linds_ubuntu_template" {
  provider                             = proxmox.linds
  acpi                                 = true
  bios                                 = "ovmf"
  boot_order                           = ["scsi0", "net0"]
  delete_unreferenced_disks_on_destroy = true
  description                          = "packer generated ubuntu"
  keyboard_layout                      = "en-us"
  mac_addresses                        = ["F2:7E:38:25:6F:13"]
  machine                              = "q35"
  migrate                              = false
  name                                 = "ubuntu"
  network_device = [{
    bridge       = "vmbr0"
    disconnected = false
    enabled      = true
    firewall     = false
    mac_address  = "F2:7E:38:25:6F:13"
    model        = "virtio"
    mtu          = 0
    queues       = 0
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 0
  }]
  node_name           = "linds-proxmox-01"
  on_boot             = false
  protection          = false
  purge_on_destroy    = true
  reboot              = false
  reboot_after_update = false
  scsi_hardware       = "virtio-scsi-single"
  started             = false
  stop_on_destroy     = false
  tablet_device       = true
  tags                = []
  template            = true
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_migrate     = 1800
  timeout_reboot      = 1800
  timeout_shutdown_vm = 1800
  timeout_start_vm    = 1800
  timeout_stop_vm     = 300
  vm_id               = 150
  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }
  cpu {
    cores      = 4
    flags      = []
    hotplugged = 0
    limit      = 0
    numa       = false
    sockets    = 1
    type       = "qemu64"
  }
  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "local-lvm"
    discard           = "on"
    file_format       = "raw"
    interface         = "scsi0"
    iothread          = true
    path_in_datastore = "base-150-disk-0"
    queues            = 0
    replicate         = false
    size              = 16
    ssd               = true
  }
  memory {
    dedicated      = 4096
    floating       = 0
    keep_hugepages = false
    shared         = 0
  }
  operating_system {
    type = "l26"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

# Ubuntu 26.04 template (151), built by Packer. Clone source for
# LINDS-Torrent-02.
resource "proxmox_virtual_environment_vm" "linds_ubuntu26_template" {
  provider                             = proxmox.linds
  acpi                                 = true
  bios                                 = "ovmf"
  boot_order                           = ["scsi0", "net0"]
  delete_unreferenced_disks_on_destroy = true
  description                          = "packer generated ubuntu 26.04"
  keyboard_layout                      = "en-us"
  mac_addresses                        = ["F6:78:33:A5:E6:7B"]
  machine                              = "q35"
  migrate                              = false
  name                                 = "ubuntu-26"
  network_device = [{
    bridge       = "vmbr0"
    disconnected = false
    enabled      = true
    firewall     = false
    mac_address  = "F6:78:33:A5:E6:7B"
    model        = "virtio"
    mtu          = 0
    queues       = 0
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 0
  }]
  node_name           = "linds-proxmox-01"
  on_boot             = false
  protection          = false
  purge_on_destroy    = true
  reboot              = false
  reboot_after_update = false
  scsi_hardware       = "virtio-scsi-single"
  started             = false
  stop_on_destroy     = false
  tablet_device       = true
  tags                = []
  template            = true
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_migrate     = 1800
  timeout_reboot      = 1800
  timeout_shutdown_vm = 1800
  timeout_start_vm    = 1800
  timeout_stop_vm     = 300
  vm_id               = 151
  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }
  cpu {
    cores      = 4
    flags      = []
    hotplugged = 0
    limit      = 0
    numa       = false
    sockets    = 1
    type       = "host"
  }
  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "local-lvm"
    discard           = "on"
    file_format       = "raw"
    interface         = "scsi0"
    iothread          = true
    path_in_datastore = "base-151-disk-0"
    queues            = 0
    replicate         = false
    size              = 16
    ssd               = true
  }
  memory {
    dedicated      = 4096
    floating       = 0
    keep_hugepages = false
    shared         = 0
  }
  operating_system {
    type = "l26"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}

# Windows Server 2025 template (160), built by Packer (../packer/windows).
# Clone source for the Windows VMs at LINDS (local.windows_template_vm_id).
resource "proxmox_virtual_environment_vm" "linds_windows_template" {
  provider                             = proxmox.linds
  acpi                                 = true
  bios                                 = "ovmf"
  boot_order                           = ["scsi0", "net0"]
  delete_unreferenced_disks_on_destroy = true
  description                          = "Windows Server 2025 Standard Evaluation (Desktop Experience), built by Packer"
  keyboard_layout                      = "en-us"
  mac_addresses                        = ["5A:E4:FD:E7:7D:F1"]
  machine                              = "pc-q35-11.0+pve2"
  migrate                              = false
  name                                 = "windows-server-2025"
  network_device = [{
    bridge       = "vmbr0"
    disconnected = false
    enabled      = true
    firewall     = false
    mac_address  = "5A:E4:FD:E7:7D:F1"
    model        = "virtio"
    mtu          = 0
    queues       = 0
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 300
  }]
  node_name           = "linds-proxmox-01"
  on_boot             = false
  protection          = false
  purge_on_destroy    = true
  reboot              = false
  reboot_after_update = false
  scsi_hardware       = "virtio-scsi-single"
  started             = false
  stop_on_destroy     = false
  tablet_device       = true
  tags                = []
  template            = true
  timeout_clone       = 1800
  timeout_create      = 1800
  timeout_migrate     = 1800
  timeout_reboot      = 1800
  timeout_shutdown_vm = 1800
  timeout_start_vm    = 1800
  timeout_stop_vm     = 300
  vm_id               = 160
  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }
  cpu {
    cores      = 4
    flags      = []
    hotplugged = 0
    limit      = 0
    numa       = false
    sockets    = 1
    type       = "host"
  }
  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "local-lvm"
    discard           = "on"
    file_format       = "raw"
    interface         = "scsi0"
    iothread          = true
    path_in_datastore = "base-160-disk-1"
    queues            = 0
    replicate         = false
    size              = 60
    ssd               = true
  }
  efi_disk {
    datastore_id      = "local-lvm"
    file_format       = "raw"
    pre_enrolled_keys = true
    type              = "4m"
  }
  memory {
    dedicated      = 8192
    floating       = 0
    keep_hugepages = false
    shared         = 0
  }
  operating_system {
    type = "win11"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}
