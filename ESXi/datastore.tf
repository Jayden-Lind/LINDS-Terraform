resource "vsphere_vmfs_datastore" "jd-datastore" {
  name           = "JD-Datastore-OS"
  host_system_id = vsphere_host.jd-esxi-01.id
  disks = [
    "naa.600508b1001c10ab7892e1eed682dcca",
  ]
}

resource "vsphere_vmfs_datastore" "linds-datastore" {
  name           = "LINDS-Datastore-OS"
  host_system_id = data.vsphere_host.LINDS-ESXi.id
  disks = [
    "naa.644a84203479530029eac16a09d3de7c",
  ]
}

resource "vsphere_vmfs_datastore" "linds-datastore-nas" {
  name           = "LINDS-Datastore-01"
  host_system_id = data.vsphere_host.LINDS-ESXi.id
  disks = [
    "naa.644a84203479530029eac1520867ed23",
  ]
}

resource "vsphere_vmfs_datastore" "linds-datastore-nas-zfs" {
  name           = "LINDS-Datastore-02"
  host_system_id = data.vsphere_host.LINDS-ESXi.id
  disks = [
    "naa.644a842034795300ff00001b01f1d217",
  ]
}