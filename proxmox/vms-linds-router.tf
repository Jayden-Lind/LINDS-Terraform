###############################################################################
# LINDS-Router-01 (114) - Debian 13 replacement for LINDS-VyOS (VM 101)
#
# The same build as JD-Router-01 (vms-jd-router.tf), on linds-proxmox-01:
#
#   * Debian genericcloud image imported straight into the disk through the
#     API (disk.import_from is create-only, so a refreshed image never touches
#     the running guest).
#   * Built beside the router it replaces. A management NIC on VLAN 300
#     (10.3.1.250, gateway LINDS-VyOS at 10.3.1.1) carries the Ansible build,
#     and the LAN and WAN NICs are created link-down, so the guest runs its
#     whole router config without a frame of it reaching the live LAN or the
#     NBN port.
#   * Both data NICs are virtio: vmbr0 (eno2, the LAN trunk, every VLAN) and
#     vmbr1 (eno1, the WAN). There is no SR-IOV here.
#
# The guest names its interfaces by MAC (systemd .link files in LINDS-Ansible
# roles/router/files/linds), so Proxmox device order is irrelevant to the
# config. The MACs are this VM's own, not LINDS-VyOS's: the two can never be
# mistaken for each other on the wire, and VyOS gets its old leases back if
# it has to be started again.
#
# LINDS-VyOS (VM 101) was made by hand and is not in this state. Nothing here
# touches it; shutting it down at cutover and deleting it afterwards are
# `qm` commands (LINDS-Ansible roles/router/README.md has the order).
#
# Apply with targets, as always in this module (README, "Usage"):
#   terraform apply \
#     -target=proxmox_storage_directory.linds_local \
#     -target=proxmox_virtual_environment_vm.linds_router
###############################################################################

# The one storage registration on linds-proxmox-01 that this module owns, and
# only because the router needs two content types the hand-made entry lacks:
# "import" (the cloud image, see storage.tf for jd-proxmox-02's) and
# "snippets" (the cloud-init file below). The directory and everything in it
# are untouched; this is the `content` line of /etc/pve/storage.cfg.
import {
  to = proxmox_storage_directory.linds_local
  id = "local"
}

resource "proxmox_storage_directory" "linds_local" {
  provider = proxmox.linds

  id      = "local"
  path    = "/var/lib/vz"
  content = ["snippets", "backup", "iso", "vztmpl", "import"]
  shared  = false
}

resource "proxmox_virtual_environment_download_file" "debian_cloud_linds" {
  provider = proxmox.linds

  content_type = "import"
  datastore_id = proxmox_storage_directory.linds_local.id
  node_name    = local.nodes.linds.name
  file_name    = "debian-13-genericcloud-amd64.qcow2"
  url          = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
  # "latest" moves; the stored file is only read at VM create time, so the
  # provider must not re-download (and fail on a checksum change) every plan.
  overwrite           = false
  overwrite_unmanaged = true
}

resource "proxmox_virtual_environment_vm" "linds_router" {
  provider  = proxmox.linds
  name      = "LINDS-Router-01"
  vm_id     = 114
  tags      = ["router"]
  node_name = local.nodes.linds.name

  # The genericcloud image has no guest agent; cloud-init installs it on the
  # first boot, so the first apply waits up to this long for it to appear.
  agent {
    enabled = true
    timeout = "5m"
  }

  # LINDS-VyOS's four cores, no pinning (it had none). The flags are the
  # fleet's: the Talos workers on this host run with the same list.
  cpu {
    type         = "host"
    architecture = "x86_64"
    cores        = 4
    flags        = local.guest_cpu_flags
  }

  # 6 GiB against VyOS's 4, as JD-Router-01: this router runs Suricata, which
  # VyOS here did not, and the unit's MemoryMax (LINDS-Ansible
  # roles/router/files/etc/systemd/system/suricata.service.d/memory.conf) is
  # sized against this figure. Raise the two together.
  memory {
    dedicated = 6144
    floating  = 0 # ballooning off
  }

  bios          = "ovmf"
  machine       = "q35"
  on_boot       = true
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]

  # Site router. Attribute writes must never restart it.
  reboot_after_update = false

  # First up, as LINDS-VyOS is. Both carry order 1 until VM 101 is retired;
  # the cutover sets VM 101's onboot off so a host reboot cannot start two
  # routers with the same addresses.
  startup {
    order = "1"
  }

  efi_disk {
    datastore_id      = local.datastores.linds
    type              = "4m"
    pre_enrolled_keys = false # no secure boot
  }

  # Proxmox web serial console (`qm terminal 114`) - the cloud image already
  # boots with console=ttyS0 on its kernel command line. This is the way in
  # when the network is the thing that is broken.
  serial_device {
    device = "socket"
  }

  disk {
    datastore_id = local.datastores.linds
    interface    = "scsi0"
    import_from  = proxmox_virtual_environment_download_file.debian_cloud_linds.id
    size         = 16
    cache        = "none"
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  initialization {
    datastore_id = local.datastores.linds
    interface    = "ide2"

    # Build-time address for the management NIC (net0). cloud-init applies it
    # on the first boot only; from the second, systemd-networkd has it from
    # LINDS-Ansible (30-mgmt0.network), which must say the same.
    ip_config {
      ipv4 {
        address = "10.3.1.250/24"
        gateway = "10.3.1.1"
      }
    }

    dns {
      servers = ["10.3.1.1"]
    }

    user_data_file_id = proxmox_virtual_environment_file.linds_router_cloud_config.id
  }

  # net0 - management, VLAN 300 (servers), for the build only. At cutover it
  # goes link-down in the same step that brings net1 and net2 up: the guest's
  # own lan0.300 then holds 10.3.1.1 on this very network.
  network_device {
    bridge       = "vmbr0"
    model        = "virtio"
    mac_address  = "BC:24:11:06:01:00"
    vlan_id      = 300
    firewall     = false
    disconnected = false
  }

  # net1 - LAN trunk. No vlan_id: untagged 192.168.6.0/24 plus tagged
  # 36/80/110/300, exactly as LINDS-VyOS's net0.
  network_device {
    bridge       = "vmbr0"
    model        = "virtio"
    mac_address  = "BC:24:11:06:01:01"
    queues       = 4
    firewall     = false
    disconnected = true # as created; see lifecycle
  }

  # net2 - WAN (vmbr1 = eno1, the NBN port), as LINDS-VyOS's net1.
  network_device {
    bridge       = "vmbr1"
    model        = "virtio"
    mac_address  = "BC:24:11:06:01:02"
    queues       = 4
    firewall     = false
    disconnected = true # as created; see lifecycle
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    # Off until cutover so the build can be torn down and redone. Flip it
    # when this becomes the router.
    prevent_destroy = false
    ignore_changes = [
      # The image is only read at create time.
      disk[0].import_from,
      # Which links are up is the cutover's to decide, on the host, with a
      # rollback (linds-router-cutover). The values above are how the VM is
      # created; without this, an apply after the swap would quietly take
      # the site's LAN and WAN down again to match them.
      network_device[0].disconnected,
      network_device[1].disconnected,
      network_device[2].disconnected,
    ]
  }
}

###############################################################################
# LINDS-Router-01 cloud-init
#
# Deliberately minimal, and the same as JD-Router-01's: identity, one user
# with the fleet SSH key, the guest agent, and the Python that Ansible needs.
# Everything else - networking, nftables, FRR, strongSwan, kea, pdns,
# Suricata - is LINDS-Ansible roles/router, so the box stays re-runnable and
# drift-checkable and no WireGuard or IPsec secret ever lands on the `local`
# datastore.
#
# The 99-disable-network-config.cfg file takes effect on the SECOND boot: this
# first boot still applies the Proxmox-generated static address on net0 (that
# is how Ansible gets in), after which systemd-networkd owns every interface.
###############################################################################

resource "proxmox_virtual_environment_file" "linds_router_cloud_config" {
  provider = proxmox.linds

  content_type = "snippets"
  datastore_id = proxmox_storage_directory.linds_local.id
  node_name    = local.nodes.linds.name

  source_raw {
    data      = <<-EOT
      #cloud-config
      hostname: linds-router-01
      fqdn: linds-router-01.linds.com.au
      preserve_hostname: false
      manage_etc_hosts: true
      timezone: Australia/Melbourne

      disable_root: true
      ssh_pwauth: false
      users:
        - name: jayden
          groups: [adm, sudo]
          sudo: "ALL=(ALL) NOPASSWD:ALL"
          shell: /bin/bash
          lock_passwd: true
          ssh_authorized_keys:
            - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDPWOKxGwpEJ/BU5h71sdPWdnuTgZzx4KRlApHZpoPJUYwDQUHYCXCHsbRrgRUTOuzCJ0Z5HAkDRBUJP8duHgtW7heCv2Emb5HfIbQFierkJnaSwjT68B9JNS8z4w6nNUPViXlPn4IN/hmt2YAWts1i+7xQf0laxyZiHvqm2CQyKUpWYg5KrGgLurZdatDAfEcTgxmVB2OzEH9JREn9pW/9wYIB3dJX5Exvbq8y4ptDiTx2q42DRybHVifIKkAKxOE/pvfTIN++7IKXq6G8uWKefrHLDzdyzpXIg+yqN/uWHb0rWRVe6wmI5EwIlL0jdro/3skbw3bSORDIpZaMWZL+F18HhNW9eW7vKGK2heWzehBlUmmwXJiR3C6qmLiv+lBMvgGB/UZ4eA9x5hvVdQ8WQDJnzdjXhnsmd9yS9btGsm4Gqz+WQGYPHs2GsLMfWlY5TAxM/Qn2Q4SDj7/QHjGsGMYQ+RhHchdjEART8Tiae/+SuA0BZxVPO6QDwLPCYVs= root@jd-dev-01"

      write_files:
        - path: /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
          permissions: "0644"
          content: |
            # Ansible (LINDS-Ansible roles/router) owns networking from the
            # second boot on. Written by Terraform cloud-init.
            network: {config: disabled}

      package_update: true
      package_upgrade: true
      packages:
        - qemu-guest-agent
        - python3
        - python3-apt
      runcmd:
        - systemctl enable --now qemu-guest-agent
    EOT
    file_name = "linds-router-01.cloud-config.yaml"
  }
}
