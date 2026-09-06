###############################################################################
# JD-Router-01 (1101) - Debian 13 replacement for JD-VyOS-01
#
# Same shape as the VyOS VM it replaces (4 cores pinned to 8-15, OVMF/q35,
# virtio-scsi-single, startup order 1) with three differences:
#
#   * Debian genericcloud image imported straight into the disk through the
#     API. No Packer template: the image is fetched by
#     proxmox_virtual_environment_download_file (content type "import", see
#     storage.tf) and disk.import_from is create-only, so a refreshed image
#     never touches the running guest.
#   * WAN is the ConnectX-4 Lx SR-IOV VF (0000:c2:00.2, hostpci0), as on
#     VyOS. sriov-wan-setup.service on the host creates VF 0 with the MAC the
#     guest's 10-wan0.link expects (BC:24:11:01:11:02), trust on, spoofchk
#     off, bound to vfio-pci. hostpci pins the VM to this host and locks its
#     memory; changes to it need a cold start.
#   * The build ran through a management NIC on VLAN 53 (10.0.53.250) with
#     lan0/wan0 link-down, so the guest could run its full router config
#     without touching the live LAN. After cutover that NIC and the virtio
#     WAN were removed; the LAN trunk is the only network_device (net0).
#
# The guest names its interfaces by MAC (systemd .link files in LINDS-Ansible
# roles/router), so Proxmox device order is irrelevant to the config.
#
# Cut over from JD-VyOS-01 on 2026-09-06; VM 1100 is kept, off, as rollback.
###############################################################################

resource "proxmox_virtual_environment_download_file" "debian_cloud_jd" {
  content_type = "import"
  datastore_id = "local"
  node_name    = local.nodes.jd.name
  file_name    = "debian-13-genericcloud-amd64.qcow2"
  url          = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
  # "latest" moves; the stored file is only read at VM create time, so the
  # provider must not re-download (and fail on a checksum change) every plan.
  overwrite           = false
  overwrite_unmanaged = true
}

resource "proxmox_virtual_environment_vm" "jd_router" {
  name      = "JD-Router-01"
  vm_id     = 1101
  tags      = ["router"]
  node_name = local.nodes.jd.name

  # The genericcloud image has no guest agent; cloud-init installs it on the
  # first boot, so the first apply waits up to this long for it to appear.
  agent {
    enabled = true
    timeout = "5m"
  }

  cpu {
    type         = "host"
    architecture = "x86_64"
    cores        = 4
    numa         = true
    affinity     = "8-15"
    flags        = local.guest_cpu_flags
  }

  # 6 GiB against VyOS's 4: Suricata with ET Open loaded plus a 1M-entry
  # pdns-recursor cache want the headroom. Trim once measured.
  memory {
    dedicated = 6144
    floating  = 0 # ballooning off
  }

  bios          = "ovmf"
  machine       = "q35"
  on_boot       = true
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]

  # Site router. As JD-DC-01: attribute writes must never restart it.
  reboot_after_update = false

  startup {
    order = "1"
  }

  efi_disk {
    datastore_id      = local.datastores.jd
    type              = "4m"
    pre_enrolled_keys = false # no secure boot
  }

  # Proxmox web serial console (`qm terminal 1101`) - the cloud image already
  # boots with console=ttyS0 on its kernel command line.
  serial_device {
    device = "socket"
  }

  disk {
    datastore_id = local.datastores.jd
    interface    = "scsi0"
    import_from  = proxmox_virtual_environment_download_file.debian_cloud_jd.id
    size         = 16
    cache        = "none"
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  initialization {
    datastore_id = local.datastores.jd
    interface    = "ide2"

    # Build-time address for the (since removed) management NIC; the guest's
    # network-config leaves them alone and Ansible owns them from the start.
    ip_config {
      ipv4 {
        address = "10.0.53.250/24"
        gateway = "10.0.53.1"
      }
    }

    dns {
      servers = ["10.0.53.1"]
    }

    user_data_file_id = proxmox_virtual_environment_file.jd_router_cloud_config.id
  }

  # net1 - LAN trunk. No vlan_id: untagged 10.0.50.0/24 plus tagged
  # 51/52/53/58/99, exactly as VyOS's net1. bridge vids 50-100 (network.tf).
  network_device {
    bridge       = "vmbr0"
    model        = "virtio"
    mac_address  = "BC:24:11:01:11:01"
    queues       = 4
    firewall     = false
    disconnected = false
  }

  hostpci {
    device = "hostpci0"
    id     = "0000:c2:00.2"
    pcie   = true
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    # Off until cutover so the build can be torn down and redone. Every other
    # guest in this file has it on; flip it when this becomes the router.
    prevent_destroy = false
    # The image is only read at create time.
    ignore_changes = [disk[0].import_from]
  }
}

###############################################################################
# JD-Router-01 cloud-init
#
# Deliberately minimal: identity, one user with the fleet SSH key, the guest
# agent, and the Python that Ansible needs. Everything else - networking,
# nftables, FRR, strongSwan, kea, pdns, Suricata - is LINDS-Ansible
# roles/router, so the box stays re-runnable and drift-checkable and no
# WireGuard/IPsec/EAP secret ever lands on the `local` datastore.
#
# The 99-disable-network-config.cfg file takes effect on the SECOND boot: this
# first boot still applies the Proxmox-generated static address on net0 (that
# is how Ansible gets in), after which systemd-networkd owns every interface.
###############################################################################

resource "proxmox_virtual_environment_file" "jd_router_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = local.nodes.jd.name

  source_raw {
    data      = <<-EOT
      #cloud-config
      hostname: jd-router-01
      fqdn: jd-router-01.linds.com.au
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
    file_name = "jd-router-01.cloud-config.yaml"
  }
}
