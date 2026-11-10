###############################################################################
# jd-proxmox-02 host networking
#
# Physical NICs are a dual-port ConnectX-4 Lx:
#   ens5f1np1 -> vmbr0 (LAN, VLAN aware)
#   ens5f0np0 -> no bridge (WAN). The router VM 1101 has VF 0 of this port
#                as its wan0 (hostpci0 in vms-jd-router.tf).
#
# There is no WAN bridge. `vmbr1` was removed on 2026-11-10: no guest used
# it, and a bridge on the PF kept the host attached to the WAN segment. Do
# not add it back. The PF stanza in /etc/network/interfaces (`auto`, and a
# pre-up line that disables IPv6 on the PF) and the VF settings
# (/usr/local/sbin/sriov-wan-setup.sh: MAC, trust off, spoofchk on) are not
# expressible through the Proxmox API and live only on the host.
#
# The ethtool tuning applied to ens5f1np1 in /etc/network/interfaces is not
# expressible through the Proxmox API and lives only in that file's post-up
# lines. Offloads are `gro on lro off tso on`: LRO must stay off on a bridging
# host, but TSO was re-enabled on 2026-09-02 - the geneve-over-IPsec GRO
# problem noted in cilium.tf was on the VyOS vti/xfrm path, not this NIC, and
# disabling TSO here only cost host/guest-to-LAN throughput.
###############################################################################

resource "proxmox_network_linux_bridge" "lan" {
  node_name = local.nodes.jd.name
  name      = "vmbr0"
  comment   = "LAN"

  address    = "10.0.50.246/24"
  gateway    = "10.0.50.1"
  vlan_aware = true
  mtu        = 1500

  # The CX-4 Lx can hardware-filter at most 512 VLANs per vport; the Proxmox
  # default of 2-4094 overflows that and forces the NIC into promiscuous
  # software filtering (dmesg: "netdev vlans list size (4094) > (512)").
  # Any new VLAN terminated on JD-VyOS-01 must be added here or its tagged
  # traffic will be dropped at the bridge. Native/untagged LAN needs no entry.
  vids = "50-100"

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
