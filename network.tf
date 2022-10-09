resource "vsphere_host_port_group" "VLAN_JD_TRUNK" {
  name                = "VLAN Trunk"
  host_system_id      = data.vsphere_host.JD-ESXi.id
  virtual_switch_name = vsphere_host_virtual_switch.jd-switch.name
  vlan_id             = 4095
}

resource "vsphere_host_port_group" "VLAN_JD_NATIVE" {
  name                = "Native VLAN"
  host_system_id      = data.vsphere_host.JD-ESXi.id
  virtual_switch_name = vsphere_host_virtual_switch.jd-switch.name
  vlan_id             = 0
}

resource "vsphere_host_port_group" "VLAN_JD_DMZ" {
  name                = "JD-DMZ"
  host_system_id      = data.vsphere_host.JD-ESXi.id
  virtual_switch_name = vsphere_host_virtual_switch.jd-switch.name
  vlan_id             = 60
}

resource "vsphere_host_port_group" "VLAN_JD_TORRENT" {
  name                = "VLAN 51 TORRENT"
  host_system_id      = data.vsphere_host.JD-ESXi.id
  virtual_switch_name = vsphere_host_virtual_switch.jd-switch.name
  vlan_id             = 51
}

resource "vsphere_host_port_group" "VLAN_JD_KUBE" {
  name                = "VLAN 52 KUBE"
  host_system_id      = data.vsphere_host.JD-ESXi.id
  virtual_switch_name = vsphere_host_virtual_switch.jd-switch.name
  vlan_id             = 52
}

resource "vsphere_host_port_group" "VLAN_JD_DEV" {
  name                = "VLAN 53 DEV"
  host_system_id      = data.vsphere_host.JD-ESXi.id
  virtual_switch_name = vsphere_host_virtual_switch.jd-switch.name
  vlan_id             = 53
}

resource "vsphere_host_port_group" "VLAN_JD_SERVER" {
  name                = "VLAN 55 Server"
  host_system_id      = data.vsphere_host.JD-ESXi.id
  virtual_switch_name = vsphere_host_virtual_switch.jd-switch.name
  vlan_id             = 55
}

resource "vsphere_host_port_group" "VLAN_LINDS_CLIENT" {
  name                = "VLAN 100"
  host_system_id      = data.vsphere_host.LINDS-ESXi.id
  virtual_switch_name = vsphere_host_virtual_switch.linds-switch.name
  vlan_id             = 100
}

resource "vsphere_host_port_group" "VLAN_LINDS_SERVER" {
  name                = "VLAN 300"
  host_system_id      = data.vsphere_host.LINDS-ESXi.id
  virtual_switch_name = vsphere_host_virtual_switch.linds-switch.name
  vlan_id             = 300
}

resource "vsphere_host_port_group" "VLAN_LINDS_TORRENT" {
  name                = "VLAN 36"
  host_system_id      = data.vsphere_host.LINDS-ESXi.id
  virtual_switch_name = vsphere_host_virtual_switch.linds-switch.name
  vlan_id             = 36
}

resource "vsphere_host_port_group" "VLAN_LINDS_TRUNK" {
  name                = "VLAN TRUNK"
  host_system_id      = data.vsphere_host.LINDS-ESXi.id
  virtual_switch_name = vsphere_host_virtual_switch.linds-switch.name
  vlan_id             = 4095
}




data "vsphere_network" "jd_network" {
  name          = vsphere_host_port_group.VLAN_JD_NATIVE.name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "JD-DMZ" {
  name          = vsphere_host_port_group.VLAN_JD_DMZ.name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "DEV" {
  name          = vsphere_host_port_group.VLAN_JD_DEV.name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "LINDS-SERVER" {
  name          = vsphere_host_port_group.VLAN_LINDS_SERVER.name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "VLAN-Trunk" {
  name          = vsphere_host_port_group.VLAN_JD_TRUNK.name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "VLAN-TRUNK" {
  name          = vsphere_host_port_group.VLAN_LINDS_TRUNK.name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "VLAN-51" {
  name          = vsphere_host_port_group.VLAN_JD_TORRENT.name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "VLAN-100" {
  name          = vsphere_host_port_group.VLAN_LINDS_CLIENT.name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "VLAN-36" {
  name          = vsphere_host_port_group.VLAN_LINDS_TORRENT.name
  datacenter_id = data.vsphere_datacenter.dc.id
}

