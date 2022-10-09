resource "vsphere_virtual_machine" "JD-Web-01" {
  name                = "JD-Web-01"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 2
  memory              = 4096
  guest_id            = "ubuntu64Guest"
  sync_time_with_host = false
  network_interface {
    network_id = data.vsphere_network.JD-DMZ.id
  }
  scsi_type = "lsilogic"
  disk {
    label            = "disk0"
    size             = 16
    thin_provisioned = false
    keep_on_remove   = true
    datastore_id     = vsphere_vmfs_datastore.jd-datastore.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "vsphere_virtual_machine" "JD-Plex-01" {
  name                    = "JD-Plex-01"
  resource_pool_id        = local.jd_host
  datastore_id            = vsphere_vmfs_datastore.jd-datastore.id
  firmware                = "efi"
  num_cpus                = 4
  memory                  = 4096
  guest_id                = "rhel9_64Guest"
  sync_time_with_host     = false
  efi_secure_boot_enabled = true
  network_interface {
    network_id = data.vsphere_network.jd_network.id
  }
  disk {
    label            = "disk0"
    size             = 16
    thin_provisioned = false
    keep_on_remove   = true
    datastore_id     = vsphere_vmfs_datastore.jd-datastore.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "vsphere_virtual_machine" "JD-Dev-02" {
  name                = "JD-Dev-02"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 4
  memory              = 16384
  firmware            = "efi"
  guest_id            = "rhel9_64Guest"
  sync_time_with_host = false
  network_interface {
    network_id = data.vsphere_network.jd_network.id
  }
  disk {
    label            = "disk0"
    size             = 50
    thin_provisioned = false
    keep_on_remove   = true
    datastore_id     = vsphere_vmfs_datastore.jd-datastore.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "vsphere_virtual_machine" "JD-Kube-01" {
  name                = "JD-Kube-01"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 2
  memory              = 8192
  firmware            = "efi"
  guest_id            = "rhel9_64Guest"
  sync_time_with_host = false
  network_interface {
    network_id = data.vsphere_network.DEV.id
  }
  disk {
    label            = "disk0"
    size             = 16
    thin_provisioned = false
    keep_on_remove   = true
    datastore_id     = vsphere_vmfs_datastore.jd-datastore.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "vsphere_virtual_machine" "JD-Kube-02" {
  name                = "JD-Kube-02"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 2
  memory              = 4096
  firmware            = "efi"
  sync_time_with_host = false
  guest_id            = "rhel9_64Guest"
  network_interface {
    network_id = data.vsphere_network.DEV.id
  }
  disk {
    label            = "disk0"
    size             = 16
    thin_provisioned = false
    keep_on_remove   = true
    datastore_id     = vsphere_vmfs_datastore.jd-datastore.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "vsphere_virtual_machine" "JD-Kube-03" {
  name                = "JD-Kube-03"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 2
  memory              = 4096
  firmware            = "efi"
  sync_time_with_host = false
  network_interface {
    network_id = data.vsphere_network.DEV.id
  }
  disk {
    label            = "disk0"
    size             = 16
    thin_provisioned = false
    keep_on_remove   = true
    datastore_id     = vsphere_vmfs_datastore.jd-datastore.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "vsphere_virtual_machine" "JD-Truenas-01" {
  name                = "JD-Truenas-01"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 4
  memory              = 16384
  firmware            = "efi"
  sync_time_with_host = false
  network_interface {
    network_id = data.vsphere_network.jd_network.id
  }
  scsi_controller_count = 2
  scsi_type             = "lsilogic-sas"
  disk {
    label            = "disk0"
    size             = 16
    thin_provisioned = false
    keep_on_remove   = true
    unit_number      = 0
    datastore_id     = vsphere_vmfs_datastore.jd-datastore.id
  }
  disk {
    label            = "disk1"
    size             = 100
    thin_provisioned = false
    keep_on_remove   = true
    unit_number      = 15
    datastore_id     = vsphere_vmfs_datastore.jd-datastore.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "vsphere_virtual_machine" "JD-Puppet-Master" {
  name                = "JD-Puppet-Master"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 2
  memory              = 4096
  firmware            = "efi"
  sync_time_with_host = false
  network_interface {
    network_id = data.vsphere_network.jd_network.id
  }
  scsi_controller_count = 1
  scsi_type             = "pvscsi"
  disk {
    label            = "disk0"
    size             = 16
    thin_provisioned = false
    keep_on_remove   = true
    unit_number      = 0
    datastore_id     = vsphere_vmfs_datastore.jd-datastore.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "vsphere_virtual_machine" "JD-Backup-01" {
  name                = "JD-Backup-01"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 2
  memory              = 2048
  firmware            = "efi"
  sync_time_with_host = false
  network_interface {
    network_id = data.vsphere_network.jd_network.id
  }
  scsi_controller_count = 1
  scsi_type             = "pvscsi"
  disk {
    label            = "disk0"
    size             = 16
    thin_provisioned = false
    keep_on_remove   = true
    unit_number      = 0
    datastore_id     = vsphere_vmfs_datastore.jd-datastore.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "vsphere_virtual_machine" "JD-OPNsense-01" {
  name                = "JD-OPNsense-01"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 4
  memory              = 4096
  firmware            = "bios"
  sync_time_with_host = false
  latency_sensitivity = "high"
  memory_reservation  = "4096"
  cpu_reservation     = "7992"
  vvtd_enabled = true
  pci_device_id       = ["0000:04:00.0"]
  network_interface {
    network_id = data.vsphere_network.VLAN-Trunk.id
  }
  scsi_controller_count = 1
  scsi_type             = "pvscsi"
  disk {
    label            = "disk0"
    size             = 16
    thin_provisioned = false
    keep_on_remove   = true
    unit_number      = 0
    datastore_id     = vsphere_vmfs_datastore.jd-datastore.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "vsphere_virtual_machine" "JD-Torrent-01" {
  name                = "JD-Torrent-01"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 4
  memory              = 8192
  firmware            = "efi"
  sync_time_with_host = false
  network_interface {
    network_id = data.vsphere_network.VLAN-51.id
  }
  scsi_controller_count = 1
  scsi_type             = "pvscsi"
  disk {
    label            = "disk0"
    size             = 16
    thin_provisioned = false
    keep_on_remove   = true
    unit_number      = 0
    datastore_id     = vsphere_vmfs_datastore.jd-datastore.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

## Unsupported due to Raw Disk Mapping

# resource "vsphere_virtual_machine" "JD-DC-01" {
#   name             = "JD-DC-01"
#   resource_pool_id = local.jd_host
#   datastore_id     = local.jd_datastore
#   num_cpus = 2
#   memory   = 4096
#   firmware = "efi"
#   sync_time_with_host = false
#   network_interface {
#     network_id = data.vsphere_network.jd_network.id
#   }
#   scsi_controller_count = 1
#   scsi_type = "pvscsi"
#   disk {
#     label            = "disk0"
#     size             = 40
#     thin_provisioned = false
#     keep_on_remove   = true
#     unit_number      = 0
#   }
#   lifecycle {
#     prevent_destroy = true
#   }
# }
