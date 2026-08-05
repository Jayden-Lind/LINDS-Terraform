###############################################################################
# jd-proxmox-02 host networking
#
# Physical NICs are a dual-port ConnectX-4 Lx:
#   ens5f1np1 -> vmbr0 (LAN, VLAN aware)
#   ens5f0np0 -> vmbr1 (WAN, handed to JD-VyOS-01)
#
# The ethtool tuning applied to ens5f1np1 in /etc/network/interfaces is not
# expressible through the Proxmox API; it is reconciled in zfs.tf's host
# tunables section instead. Notably `gro on lro off tso off` - see the
# geneve-over-IPsec notes in the repo README.
###############################################################################

resource "proxmox_network_linux_bridge" "lan" {
  node_name = local.nodes.jd.name
  name      = "vmbr0"
  comment   = "LAN"

  address    = "10.0.50.246/24"
  gateway    = "10.0.50.1"
  vlan_aware = true
  mtu        = 1500

  ports = ["ens5f1np1"]
}

# Storage leg on VLAN 53: gives the host an L2-direct path to the Talos nodes
# so NFS/iSCSI no longer hairpins through the VyOS router VM.
# jd-truenas-01.linds.com.au and the democratic-csi targetPortal both point here.
resource "proxmox_network_linux_vlan" "storage_vlan53" {
  node_name = local.nodes.jd.name
  name      = "vmbr0.53"
  comment   = "k8s storage - direct L2 to VLAN 53"

  address = "10.0.53.246/24"
}

resource "proxmox_network_linux_bridge" "wan" {
  node_name = local.nodes.jd.name
  name      = "vmbr1"
  comment   = "WAN"

  ports = ["ens5f0np0"]
}
