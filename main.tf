provider "vsphere" {
  vsphere_server       = var.vsphere_server
  user                 = var.vsphere_user
  password             = var.vsphere_password
  allow_unverified_ssl = true
}

resource "vsphere_license" "host_licensekey" {
  license_key = var.host_licensekey
}

data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_host" "JD-ESXi" {
  name          = var.jd-host
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_host" "LINDS-ESXi" {
  name          = var.linds-host
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "jd-centos-9" {
  name          = "/${var.datacenter}/vm/${var.jd_centos_9}"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "jd-centos-8" {
  name          = "/${var.datacenter}/vm/${var.jd_centos_8}"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "linds-centos-9" {
  name          = "/${var.datacenter}/vm/${var.linds_centos_9}"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "linds-centos-8" {
  name          = "/${var.datacenter}/vm/${var.linds_centos_8}"
  datacenter_id = data.vsphere_datacenter.dc.id
}

locals {
  jd_host             = data.vsphere_host.JD-ESXi.resource_pool_id
  jd_datastore        = vsphere_vmfs_datastore.jd-datastore.id
  jd_centos_9         = data.vsphere_virtual_machine.jd-centos-9.id
  jd_centos_8         = data.vsphere_virtual_machine.jd-centos-8.id
  linds_datastore     = vsphere_vmfs_datastore.linds-datastore.id
  linds_host          = data.vsphere_host.LINDS-ESXi.resource_pool_id
  linds_centos_9      = data.vsphere_virtual_machine.linds-centos-9.id
  linds_centos_8      = data.vsphere_virtual_machine.linds-centos-8.id
  linds_datastore_nas = vsphere_vmfs_datastore.linds-datastore.id
}

