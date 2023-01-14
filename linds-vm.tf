resource "vsphere_virtual_machine" "LINDS-Kube-02" {
  name             = "LINDS-Kube-02"
  resource_pool_id = local.linds_host
  datastore_id     = vsphere_vmfs_datastore.linds-datastore.id
  num_cpus         = 2
  memory           = 4096
  guest_id         = "centos8_64Guest"
  firmware            = "efi"
  disk {
    label            = "disk0"
    thin_provisioned = true
    size             = 16
    datastore_id     = vsphere_vmfs_datastore.linds-datastore.id
  }
  network_interface {
    network_id = data.vsphere_network.LINDS-SERVER.id
  }
  clone {
    template_uuid = local.linds_centos_9
    customize {
      linux_options {
        host_name    = "LINDS-Kube-02"
        domain       = "linds.com.au"
        hw_clock_utc = false
      }
      network_interface {}
    }
  }
}

resource "vsphere_virtual_machine" "LINDS-BACKUP" {
  name                 = "LINDS-BACKUP"
  resource_pool_id     = local.linds_host
  datastore_id         = vsphere_vmfs_datastore.linds-datastore.id
  num_cpus             = 6
  num_cores_per_socket = 3
  memory               = 6144
  memory_reservation   = 6144
  firmware             = "efi"
  sync_time_with_host  = false
  tools_upgrade_policy = "upgradeAtPowerCycle"
  network_interface {
    network_id = data.vsphere_network.VLAN-100.id
  }
  scsi_controller_count = 2
  scsi_type             = "pvscsi"
  disk {
    label            = "disk0"
    size             = 45
    thin_provisioned = true
    keep_on_remove   = true
    unit_number      = 0
    datastore_id     = vsphere_vmfs_datastore.linds-datastore.id
  }
  disk {
    label            = "disk1"
    size             = 11172
    thin_provisioned = false
    keep_on_remove   = true
    unit_number      = 1
    datastore_id     = vsphere_vmfs_datastore.linds-datastore-nas.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "vsphere_virtual_machine" "LINDS-DC" {
  name                             = "LINDS-DC"
  resource_pool_id                 = local.linds_host
  datastore_id                     = vsphere_vmfs_datastore.linds-datastore.id
  enable_disk_uuid                 = true
  num_cpus                         = 8
  num_cores_per_socket             = 8
  memory                           = 16384
  firmware                         = "efi"
  sync_time_with_host              = false
  sync_time_with_host_periodically = false
  tools_upgrade_policy             = "upgradeAtPowerCycle"
  network_interface {
    network_id = data.vsphere_network.LINDS-SERVER.id
  }
  scsi_controller_count = 2
  scsi_type             = "pvscsi"
  disk {
    label            = "disk0"
    size             = 80
    thin_provisioned = true
    keep_on_remove   = true
    unit_number      = 0
    datastore_id     = vsphere_vmfs_datastore.linds-datastore.id
  }
  disk {
    label            = "disk1"
    size             = 11172
    thin_provisioned = false
    keep_on_remove   = true
    unit_number      = 1
    datastore_id     = vsphere_vmfs_datastore.linds-datastore-nas.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "vsphere_virtual_machine" "LINDS-DC2" {
  name                             = "LINDS-DC2"
  resource_pool_id                 = local.linds_host
  datastore_id                     = vsphere_vmfs_datastore.linds-datastore.id
  enable_disk_uuid                 = true
  num_cpus                         = 4
  num_cores_per_socket             = 2
  memory                           = 4096
  memory_reservation               = 4096
  firmware                         = "efi"
  sync_time_with_host              = false
  sync_time_with_host_periodically = false
  tools_upgrade_policy             = "upgradeAtPowerCycle"
  network_interface {
    network_id = data.vsphere_network.LINDS-SERVER.id
  }
  scsi_controller_count = 1
  scsi_type             = "lsilogic-sas"
  disk {
    label            = "disk0"
    size             = 50
    thin_provisioned = false
    keep_on_remove   = true
    unit_number      = 0
    datastore_id     = vsphere_vmfs_datastore.linds-datastore.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "vsphere_virtual_machine" "LINDS-Kube-01" {
  name                = "LINDS-Kube-01"
  resource_pool_id    = local.linds_host
  datastore_id        = vsphere_vmfs_datastore.linds-datastore.id
  num_cpus            = 2
  memory              = 4096
  firmware            = "efi"
  sync_time_with_host = false
  guest_id = "centos8_64Guest"
  clone {
    template_uuid = local.linds_centos_9
    customize {
      linux_options {
        host_name    = "LINDS-Kube-01"
        domain       = "linds.com.au"
        hw_clock_utc = false
      }
      network_interface {}
    }
  }
  network_interface {
    network_id = data.vsphere_network.LINDS-SERVER.id
  }
  disk {
    label            = "disk0"
    size             = 20
    thin_provisioned = false
    keep_on_remove   = true
    datastore_id     = vsphere_vmfs_datastore.linds-datastore.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "vsphere_virtual_machine" "LINDS-Plex-01" {
  name                    = "LINDS-Plex-01"
  resource_pool_id        = local.linds_host
  datastore_id            = vsphere_vmfs_datastore.linds-datastore.id
  firmware                = "efi"
  num_cpus                = 4
  memory                  = 4096
  sync_time_with_host     = false
  efi_secure_boot_enabled = false
  network_interface {
    network_id = data.vsphere_network.LINDS-SERVER.id
  }
  disk {
    label            = "disk0"
    size             = 16
    thin_provisioned = false
    keep_on_remove   = true
    datastore_id     = vsphere_vmfs_datastore.linds-datastore.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "vsphere_virtual_machine" "LINDS-Truenas-01" {
  name                = "LINDS-Truenas-01"
  resource_pool_id    = local.linds_host
  datastore_id        = vsphere_vmfs_datastore.linds-datastore.id
  num_cpus            = 4
  memory              = 8192
  firmware            = "efi"
  sync_time_with_host = false
  network_interface {
    network_id = data.vsphere_network.LINDS-SERVER.id
  }
  scsi_controller_count = 2
  scsi_type             = "lsilogic-sas"
  disk {
    label            = "disk0"
    size             = 16
    thin_provisioned = false
    keep_on_remove   = true
    unit_number      = 0
    datastore_id     = vsphere_vmfs_datastore.linds-datastore.id
  }
  disk {
    label            = "disk1"
    size             = 11172
    thin_provisioned = false
    keep_on_remove   = true
    unit_number      = 1
    datastore_id     = vsphere_vmfs_datastore.linds-datastore-nas-zfs.id
  }
  disk {
    label            = "disk2"
    size             = 100
    thin_provisioned = false
    keep_on_remove   = true
    unit_number      = 15
    datastore_id     = vsphere_vmfs_datastore.linds-datastore.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "vsphere_virtual_machine" "LINDS-Torrent" {
  name                    = "LINDS-Torrent"
  resource_pool_id        = local.linds_host
  datastore_id            = vsphere_vmfs_datastore.linds-datastore.id
  firmware                = "efi"
  num_cpus                = 6
  memory                  = 4096
  sync_time_with_host     = false
  efi_secure_boot_enabled = false
  network_interface {
    network_id = data.vsphere_network.VLAN-36.id
  }
  disk {
    label            = "disk0"
    size             = 16
    thin_provisioned = false
    keep_on_remove   = true
    datastore_id     = vsphere_vmfs_datastore.linds-datastore.id
  }
  lifecycle {
    prevent_destroy = true
  }
}


resource "vsphere_virtual_machine" "LINDS-OPNsense-01" {
  name                = "LINDS-OPNsense-01"
  resource_pool_id    = local.linds_host
  datastore_id        = vsphere_vmfs_datastore.linds-datastore.id
  num_cpus            = 4
  memory              = 4096
  firmware            = "bios"
  sync_time_with_host = false
  latency_sensitivity = "high"
  memory_reservation  = "4096"
  cpu_reservation     = "9588"
  pci_device_id       = ["0000:01:00.0"]
  enable_logging      = true
  network_interface {
    network_id = data.vsphere_network.VLAN-TRUNK.id
  }
  scsi_controller_count = 1
  scsi_type             = "lsilogic-sas"
  disk {
    label            = "disk0"
    size             = 16
    thin_provisioned = false
    keep_on_remove   = true
    unit_number      = 0
    datastore_id     = vsphere_vmfs_datastore.linds-datastore.id
  }
  cdrom {
    client_device = false
    datastore_id  = local.linds_datastore
    path          = "OPNsense-22.1.2-OpenSSL-dvd-amd64.iso"
  }
  lifecycle {
    prevent_destroy = true
  }
}