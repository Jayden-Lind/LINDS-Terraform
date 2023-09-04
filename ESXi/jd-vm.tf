data "vsphere_host_thumbprint" "jd-thumbprint" {
  address = "jd-esxi-01.linds.com.au"
  insecure = true
}

resource "vsphere_host" "jd-esxi-01" {
  hostname = "jd-esxi-01.linds.com.au"
  username = var.jd-username
  password = var.jd-password
  license = "HG00K-03H8K-48929-8K1NP-3LUJ4"
  thumbprint = data.vsphere_host_thumbprint.jd-thumbprint.id
}

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
    ignore_changes = [
      ept_rvi_mode,
      hv_mode
    ]
  }
}

resource "vsphere_virtual_machine" "JD-Plex-01" {
  name                    = "JD-Plex-01"
  resource_pool_id = local.jd_host
  datastore_id            = vsphere_vmfs_datastore.jd-datastore.id
  firmware                = "efi"
  num_cpus                = 4
  num_cores_per_socket    = 4
  memory                  = 4096
  guest_id                = "rhel9_64Guest"
  sync_time_with_host     = false
  efi_secure_boot_enabled = false
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
    ignore_changes = [
      ept_rvi_mode,
      hv_mode
    ]
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
    ignore_changes = [
      ept_rvi_mode,
      hv_mode
    ]
  }
}

resource "vsphere_virtual_machine" "JD-Kube-01" {
  name                = "JD-Kube-01"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 2
  num_cores_per_socket = 2
  memory              = 8192
  firmware            = "efi"
  guest_id            = "centos8_64Guest"
  sync_time_with_host = false
  clone {
    template_uuid = local.jd_centos_9
    customize {
      linux_options {
        host_name    = "JD-Kube-01"
        domain       = "linds.com.au"
        hw_clock_utc = false
      }
      network_interface {}
    }
  }
  network_interface {
    network_id = data.vsphere_network.DEV.id
  }
  disk {
    label            = "disk0"
    size             = 20
    thin_provisioned = false
    keep_on_remove   = true
    datastore_id     = vsphere_vmfs_datastore.jd-datastore.id
  }
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      ept_rvi_mode,
      hv_mode
    ]
  }
}

resource "vsphere_virtual_machine" "JD-Kube-02" {
  name                = "JD-Kube-02"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 2
  num_cores_per_socket = 2
  memory              = 4096
  firmware            = "efi"
  sync_time_with_host = false
  guest_id            = "centos8_64Guest"
  network_interface {
    network_id = data.vsphere_network.DEV.id
  }
  clone {
    template_uuid = local.jd_centos_9
    customize {
      linux_options {
        host_name    = "JD-Kube-02"
        domain       = "linds.com.au"
        hw_clock_utc = false
      }
      network_interface {}
    }
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
    ignore_changes = [
      ept_rvi_mode,
      hv_mode
    ]
  }
}

resource "vsphere_virtual_machine" "JD-Kube-03" {
  name                = "JD-Kube-03"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 2
  num_cores_per_socket = 2
  memory              = 4096
  firmware            = "efi"
  sync_time_with_host = false
  guest_id = "centos8_64Guest"
  network_interface {
    network_id = data.vsphere_network.DEV.id
    mac_address = "00:50:56:ae:87:fd"
    use_static_mac = true
  }
  disk {
    label            = "disk0"
    size             = 16
    thin_provisioned = false
    keep_on_remove   = true
    datastore_id     = vsphere_vmfs_datastore.jd-datastore.id
  }
  clone {
    template_uuid = local.jd_centos_9
    customize {
      linux_options {
        host_name    = "JD-Kube-03"
        domain       = "linds.com.au"
        hw_clock_utc = false
      }
      network_interface {}
    }
  }
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      ept_rvi_mode,
      hv_mode
    ]
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
    ignore_changes = [
      ept_rvi_mode,
      hv_mode
    ]
  }
}

resource "vsphere_virtual_machine" "JD-Backup-01" {
  name                = "JD-Backup-01"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 2
  num_cores_per_socket = 2
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
    ignore_changes = [
      ept_rvi_mode,
      hv_mode
    ]
  }
}

resource "vsphere_virtual_machine" "JD-Torrent-01" {
  name                = "JD-Torrent-01"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 4
  num_cores_per_socket = 4
  memory              = 8192
  firmware            = "efi"
  sync_time_with_host = false
  guest_id            = "centos8_64Guest"
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
  clone {
    template_uuid = local.jd_centos_9
    customize {
      linux_options {
        host_name    = "JD-Torrent-01"
        domain       = "linds.com.au"
        hw_clock_utc = false
      }
      network_interface {}
    }
  }
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      ept_rvi_mode,
      hv_mode
    ]
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

resource "vsphere_virtual_machine" "JD-Ansible-01" {
  name                = "JD-Ansible-01"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 2
  num_cores_per_socket = 2
  memory              = 4096
  firmware            = "efi"
  sync_time_with_host = false
  guest_id = "centos8_64Guest"
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
  clone {
    template_uuid = local.jd_centos_9
    customize {
      linux_options {
        host_name    = "JD-Ansible-01"
        domain       = "linds.com.au"
        hw_clock_utc = false
      }
      network_interface {}
    }
  }
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      ept_rvi_mode,
      hv_mode
    ]
  }
}

resource "vsphere_virtual_machine" "JD-TRUEnas-01" {
  name                = "JD-TrueNAS-02"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 8
  num_cores_per_socket = 8
  memory              = 16384
  firmware            = "efi"
  sync_time_with_host = false
  guest_id            = "centos8_64Guest"

  scsi_controller_count = 2

  network_interface {
    network_id = data.vsphere_network.DEV.id
    use_static_mac = true
  }
  disk {
    label            = "disk0"
    size             = 16
    thin_provisioned = false
    keep_on_remove   = true
    datastore_id     = vsphere_vmfs_datastore.jd-datastore.id
  }

  disk {
    label            = "disk1"
    size             = 100
    thin_provisioned = false
    keep_on_remove   = true
    datastore_id     = vsphere_vmfs_datastore.jd-datastore.id
    unit_number      = 15
  }

  cdrom {
    datastore_id = vsphere_vmfs_datastore.jd-datastore.id
    path         = "TrueNAS-SCALE-22.12.3.2.iso"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      ept_rvi_mode,
      hv_mode
    ]
  }

}

resource "vsphere_virtual_machine" "JD-Minecraft-01" {
  name                = "JD-Minecraft-01"
  resource_pool_id    = local.jd_host
  datastore_id        = vsphere_vmfs_datastore.jd-datastore.id
  num_cpus            = 8
  num_cores_per_socket = 4
  memory              = 32768
  firmware            = "efi"
  sync_time_with_host = false
  guest_id = "centos8_64Guest"
  network_interface {
    network_id = data.vsphere_network.DEV.id
  }
  disk {
    label            = "disk0"
    size             = 50
    thin_provisioned = false
    keep_on_remove   = true
    datastore_id     = vsphere_vmfs_datastore.jd-datastore.id
  }
  clone {
    template_uuid = local.jd_centos_9
    customize {
      linux_options {
        host_name    = "JD-minecraft-01"
        domain       = "linds.com.au"
        hw_clock_utc = false
      }
      network_interface {}
    }
  }
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      ept_rvi_mode,
      hv_mode
    ]
  }
}