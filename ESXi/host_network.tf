resource "vsphere_host_virtual_switch" "jd-switch" {
  name                   = "vSwitch0"
  host_system_id         = vsphere_host.jd-esxi-01.id
  network_adapters       = ["vmnic8"]
  active_nics            = ["vmnic8"]
  standby_nics           = []
  allow_forged_transmits = true
  allow_mac_changes      = true
  allow_promiscuous      = true
  mtu                    = 1500
}

resource "vsphere_host_virtual_switch" "jd-switch-wan" {
  name                   = "WAN"
  host_system_id         = vsphere_host.jd-esxi-01.id
  network_adapters       = ["vmnic9"]
  active_nics            = ["vmnic9"]
  standby_nics           = []
  allow_forged_transmits = true
  allow_mac_changes      = true
  allow_promiscuous      = true
  mtu                    = 1500
  number_of_ports        = 1024
}

resource "vsphere_host_virtual_switch" "linds-switch" {
  name                   = "vSwitch0"
  host_system_id         = data.vsphere_host.LINDS-ESXi.id
  network_adapters       = ["vmnic1"]
  active_nics            = ["vmnic1"]
  standby_nics           = []
  allow_forged_transmits = true
  allow_mac_changes      = true
  allow_promiscuous      = true
}

resource "vsphere_vnic" "jd-vnic" {
  host      = vsphere_host.jd-esxi-01.id
  portgroup = vsphere_host_port_group.JD_MANAGEMENT.name
  ipv4 {
    ip      = "10.0.50.245"
    netmask = "255.255.255.0"
    gw      = "10.0.50.1"
  }
  services = [ "management", "vmotion" ]
  netstack = "defaultTcpipStack"
}

resource "vsphere_host_port_group" "JD_MANAGEMENT" {
  name                = "JD - Management Network"
  host_system_id      = vsphere_host.jd-esxi-01.id
  virtual_switch_name = vsphere_host_virtual_switch.jd-switch.name
  vlan_id             = 0
  notify_switches     = true
  standby_nics = [
    "vmnic8",
  ]
  teaming_policy = "loadbalance_srcid"
  failback       = true
}

resource "vsphere_vnic" "linds-vnic" {
  host      = data.vsphere_host.LINDS-ESXi.id
  portgroup = vsphere_host_port_group.LINDS_MANAGEMENT.name
  ipv4 {
    ip      = "10.0.0.6"
    netmask = "255.255.255.0"
    gw      = "10.0.0.1"
  }
  services = [ "management", "vmotion" ]
  netstack = "defaultTcpipStack"
}

resource "vsphere_host_port_group" "LINDS_MANAGEMENT" {
  name                = "LINDS - Management Network"
  host_system_id      = data.vsphere_host.LINDS-ESXi.id
  virtual_switch_name = vsphere_host_virtual_switch.linds-switch.name
  vlan_id             = 0
  notify_switches     = true
  active_nics = [
    "vmnic1",
  ]
  teaming_policy = "loadbalance_srcid"
  failback       = true
}