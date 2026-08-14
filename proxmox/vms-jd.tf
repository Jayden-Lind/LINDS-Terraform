###############################################################################
# Talos cluster nodes - JD site (jd-proxmox-02)
#
# Nodes get their addresses from DHCP reservations keyed on the MACs below:
#   talos-cp-01     10.0.53.200
#   talos-worker-01 10.0.53.201
#   talos-worker-02 10.0.53.202
#   talos-worker-03 10.0.53.203
###############################################################################

module "talos_cp_jd" {
  source = "./modules/talos-node"

  nodes = {
    "talos-cp-01" = { mac_address = "BC:24:11:D4:F3:C1" }
  }

  role           = "controlplane"
  node_name      = local.nodes.jd.name
  datastore_id   = local.datastores.jd
  cores          = 8
  memory         = 16384
  cpu_flags      = local.guest_cpu_flags
  vlan_id        = 53
  network_queues = 8
}

module "talos_workers_jd" {
  source = "./modules/talos-node"

  nodes = {
    "talos-worker-01" = { mac_address = "02:24:11:d4:f3:d1" }
    "talos-worker-02" = { mac_address = "02:24:11:d4:f3:d2" }
    "talos-worker-03" = { mac_address = "02:24:11:d4:f3:d3" }
  }

  role           = "worker"
  node_name      = local.nodes.jd.name
  datastore_id   = local.datastores.jd
  cores          = 8
  memory         = 16384
  cpu_flags      = local.guest_cpu_flags
  vlan_id        = 53
  network_queues = 8
}

###############################################################################
# JD-VyOS-01 (1100) - site router - DELIBERATELY NOT MANAGED HERE
#
# Adopting this VM went wrong, and the reason is structural rather than a
# tuning problem: the router has a NIC at net1 and nothing at net0, and the
# provider models network devices as a dense list. The empty index 0 in state
# got materialised into a real `net0: virtio=BC:24:11:BF:02:70` on the host.
#
# `enabled = false` does not prevent this - the provider deprecated that
# attribute precisely because it no longer suppresses the device - and
# `ignore_changes` does not help either, because it makes the *state* value
# authoritative and the state is what carries the empty slot.
#
# This VM terminates the IPsec tunnel to LINDS, is BGP peer 64550, and holds an
# SR-IOV VF for its WAN leg. It is not worth risking to save a `qm` command, so
# it is managed by hand. See removed.tf.
#
# To bring it back under Terraform, renumber its NIC to net0 inside VyOS during
# a maintenance window - then the list is dense and the model is honest. The
# resource definition is preserved in git history if you want it back.
###############################################################################

###############################################################################
# JD-DC-01 (1102) - Windows domain controller / file server
#
# scsi1 is the 14.2 TiB zvol on the NAS-SSD raidz1 that holds the bulk file
# shares. Destroying this VM would take that zvol with it.
###############################################################################

resource "proxmox_virtual_environment_vm" "jd_dc" {
  name      = "JD-DC-01"
  vm_id     = 1102
  node_name = local.nodes.jd.name

  agent {
    enabled = true
  }

  cpu {
    type         = "host"
    architecture = "x86_64"
    cores        = 8
    numa         = true
    # As local.guest_cpu_flags, plus -nested-virt: no Hyper-V / WSL2 in here,
    # and disabling it lets the guest run without the nested-paging tax.
    flags = concat(["-nested-virt"], local.guest_cpu_flags)
  }

  memory {
    dedicated = 32784
    floating  = 0 # ballooning off
  }

  bios    = "ovmf"
  machine = "pc-q35-11.0+pve2"
  on_boot = true

  # Domain controller and file server. Same reasoning as JD-VyOS-01: attribute
  # writes must never trigger a restart behind your back.
  reboot_after_update = false

  boot_order    = ["scsi0"]
  scsi_hardware = "virtio-scsi-single"

  startup {
    order    = "2"
    up_delay = "100"
  }

  disk {
    datastore_id = local.datastores.jd
    interface    = "scsi0"
    size         = 40
    cache        = "writeback"
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    mac_address = "BC:24:11:6E:FE:3F"
    queues      = 8
  }

  operating_system {
    type = "win11"
  }

  lifecycle {
    prevent_destroy = true
  }
}

###############################################################################
# JD-FS-01 (1103) - Windows Server 2025 file server
#
# Takes the bulk file shares off JD-DC-01 so SMB signing can be turned off on
# them. A domain controller cannot do that: the Default Domain Controllers
# Policy requires signing on the server side, and that requirement is what
# costs the Linux clients their throughput. A domain member has no such floor,
# so the shares move to one.
#
# Server 2025 still requires signing out of the box - it inherited the 24H2
# default - so it is disabled explicitly inside the guest, not by omission.
# That is deliberate. This host serves a single-tenant LAN, the same tradeoff
# the guest CPU flags in locals.tf already make. Do not "fix" it.
#
# scsi1 is not here yet. It is JD-DC-01's 14.2 TiB NAS-SSD zvol, which arrives
# by PVE disk reassign rather than a copy - NAS-SSD has 6.93 TiB free against
# 8.99 TiB written, so there is no room to hold both. See README.md.
###############################################################################

resource "proxmox_virtual_environment_vm" "jd_fs" {
  name      = "JD-FS-01"
  vm_id     = 1103
  node_name = local.nodes.jd.name

  # Flip to true once the virtio guest agent is installed. Enabling it before
  # then makes every read block for agent.timeout, the same trap JD-VyOS-01
  # documents in README.md.
  agent {
    enabled = false
  }

  cpu {
    type         = "host"
    architecture = "x86_64"
    cores        = 8
    numa         = true
    # As JD-DC-01: no Hyper-V or WSL2 in here, so drop the nested-paging tax.
    flags = concat(["-nested-virt"], local.guest_cpu_flags)
  }

  memory {
    dedicated = 16384
    floating  = 0 # ballooning off
  }

  bios    = "ovmf"
  machine = "pc-q35-11.0+pve2"
  on_boot = true

  # File server holding live shares. As JD-DC-01: attribute writes must never
  # trigger a restart behind your back.
  reboot_after_update = false

  # JD-DC-01 runs OVMF with no EFI vars disk and survives only on the
  # \EFI\BOOT\BOOTX64.EFI fallback. Not repeating that here.
  efi_disk {
    datastore_id      = local.datastores.jd
    type              = "4m"
    pre_enrolled_keys = false # no secure boot; Server 2025 does not need it
  }

  boot_order    = var.windows_server_iso_file_id != null ? ["scsi0", "ide2"] : ["scsi0"]
  scsi_hardware = "virtio-scsi-single"

  startup {
    order    = "3" # after JD-DC-01
    up_delay = "60"
  }

  disk {
    datastore_id = local.datastores.jd
    interface    = "scsi0"
    size         = 80
    cache        = "writeback"
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  # Install media only. Setting windows_server_iso_file_id back to null after
  # the build detaches the drive and shortens boot_order to match.
  dynamic "cdrom" {
    for_each = var.windows_server_iso_file_id != null ? [1] : []

    content {
      file_id   = var.windows_server_iso_file_id
      interface = "ide2"
    }
  }

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    mac_address = "BC:24:11:F5:01:03"
    queues      = 8
  }

  operating_system {
    type = "win11"
  }

  lifecycle {
    prevent_destroy = true
  }
}

###############################################################################
# JD-Minecraft-01 (1110) - stopped
#
# Predates the rest of the fleet: still on SeaBIOS/i440fx with the LSI SCSI
# controller and no NIC, and it carries an orphaned `unused0` volume on
# local-lvm that Terraform does not model. See README for the cleanup notes.
###############################################################################

resource "proxmox_virtual_environment_vm" "jd_minecraft" {
  name      = "JD-Minecraft-01"
  vm_id     = 1110
  node_name = local.nodes.jd.name

  started = false
  on_boot = false

  cpu {
    cores = 8
  }

  memory {
    dedicated = 32768
  }

  boot_order = ["scsi0"]

  # No scsihw line on the host, i.e. the PVE default. Pinned explicitly so
  # Terraform does not "helpfully" move it to virtio-scsi-pci, which the
  # installed guest was not built against.
  scsi_hardware = "lsi"

  disk {
    datastore_id = local.datastores.jd
    interface    = "scsi0"
    size         = 50
  }

  lifecycle {
    prevent_destroy = true
  }
}

###############################################################################
# JD-Dev-02 (1111) - stopped scratch VM on VLAN 58
###############################################################################

resource "proxmox_virtual_environment_vm" "jd_dev" {
  name      = "JD-Dev-02"
  vm_id     = 1111
  node_name = local.nodes.jd.name

  started = false
  on_boot = false

  cpu {
    type         = "host"
    architecture = "x86_64"
    cores        = 4
  }

  memory {
    dedicated = 16384
  }

  bios       = "ovmf"
  machine    = "q35"
  boot_order = ["scsi0"]

  scsi_hardware = "virtio-scsi-pci"

  disk {
    datastore_id = local.datastores.jd
    interface    = "scsi0"
    size         = 50
  }

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    mac_address = "BC:24:11:51:74:1A"
    vlan_id     = 58
    firewall    = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

###############################################################################
# JD-Torrent-01 (104) - cloned from the packer Ubuntu LTS template
###############################################################################

resource "proxmox_virtual_environment_vm" "jd_torrent" {
  name      = "JD-Torrent-01"
  tags      = ["torrent"]
  node_name = local.nodes.jd.name

  agent {
    enabled = true
  }

  cpu {
    type         = "host"
    architecture = "x86_64"
    cores        = 8
    flags        = local.guest_cpu_flags
    numa         = true
  }

  memory {
    dedicated = 16384
  }

  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"

  startup {
    order      = "6"
    up_delay   = "60"
    down_delay = "60"
  }

  disk {
    datastore_id = local.datastores.jd
    interface    = "scsi0"
    size         = 16
    iothread     = true
    discard      = "ignore"
  }

  clone {
    vm_id = local.ubuntu_template_vm_id
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 0
    queues  = 8
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = [clone]
  }
}

###############################################################################
# JD-Jump-01 (1112) - Ubuntu jumpbox, cloned from the packer template
#
# Admin workstation for running Claude Code against the cluster, so it sits on
# the untagged LAN (VLAN 50) with the Proxmox host and the rest of the fleet
# rather than behind the VyOS router.
#
# `vlan_id = 0` is that untagged LAN, not "no VLAN": vmbr0 carries 10.0.50.0/24
# natively - the host itself is 10.0.50.246 on the bridge with no tag - and
# tagged legs like vmbr0.53 hang off it. JD-Torrent-01 does the same thing.
#
# Address comes from DHCP. The MAC is pinned so a reservation can be added on
# the router later without disturbing this resource.
###############################################################################

resource "proxmox_virtual_environment_vm" "jd_jump" {
  name      = "JD-Jump-01"
  vm_id     = 1112
  tags      = ["jumpbox"]
  node_name = local.nodes.jd.name

  agent {
    enabled = true
  }

  cpu {
    type         = "host"
    architecture = "x86_64"
    cores        = 4
    flags        = local.guest_cpu_flags
    numa         = true
  }

  memory {
    dedicated = 8192
    floating  = 0 # ballooning off
  }

  bios          = "ovmf"
  machine       = "q35"
  on_boot       = true
  scsi_hardware = "virtio-scsi-single"

  startup {
    order      = "7" # after JD-Torrent-01
    up_delay   = "30"
    down_delay = "30"
  }

  # 64 GiB against the template's 16. The template enables
  # expand-root-lv.service, so the LV and filesystem grow into the extra space
  # on first boot without anything being run by hand.
  disk {
    datastore_id = local.datastores.jd
    interface    = "scsi0"
    size         = 64
    cache        = "writeback"
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  clone {
    vm_id = local.ubuntu_template_vm_id
  }

  initialization {
    datastore_id = local.datastores.jd

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.jump_cloud_config.id
  }

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    mac_address = "BC:24:11:5A:1B:12"
    vlan_id     = 0
    queues      = 4
  }

  operating_system {
    type = "l26"
  }

  # As JD-Torrent-01: the clone source is only read at create time, and the
  # provider reports drift against it forever otherwise.
  lifecycle {
    ignore_changes = [clone]
  }
}

###############################################################################
# Cloud-init snippet used by cloned guests
###############################################################################

resource "proxmox_virtual_environment_file" "kube_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = local.nodes.jd.name

  source_raw {
    data      = <<-EOF
      #cloud-config
      package_update: true
      package_upgrade: true
      packages:
        - qemu-guest-agent
    EOF
    file_name = "kube.cloud-config.yaml"
  }
}

###############################################################################
# JD-Jump-01 cloud-init
#
# Supplying user_data_file_id replaces the user-data Proxmox would otherwise
# generate, including the SSH keys - hence the users block below. The `jayden`
# account already exists in the template from the Packer autoinstall; this
# re-asserts the key so the guest is reachable even if that ever changes.
#
# Claude Code comes from Anthropic's signed apt repository, not npm. The npm
# package wants Node 22+ and Ubuntu 24.04 ships Node 18, so the npm route
# needs NodeSource bolted on first; the .deb carries the same native binary
# with no Node runtime at all. Note this is claude-code, not the claude-desktop
# repo - that one is the GUI app and this guest is headless.
#
# The apt install does not auto-update itself the way the native installer
# does - new versions arrive through `apt upgrade` like anything else.
#
# No credentials are baked in. Claude Code authenticates against the Max
# subscription interactively - run `claude` and use /login. Do not set
# ANTHROPIC_API_KEY here; that bills per token instead.
###############################################################################

resource "proxmox_virtual_environment_file" "jump_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = local.nodes.jd.name

  source_raw {
    data      = <<-EOF
      #cloud-config
      hostname: jd-jump-01
      fqdn: jd-jump-01.linds.com.au
      preserve_hostname: false
      timezone: Australia/Melbourne

      users:
        - name: jayden
          groups: [adm, sudo]
          sudo: "ALL=(ALL) NOPASSWD:ALL"
          shell: /bin/bash
          lock_passwd: false
          ssh_authorized_keys:
            - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDPWOKxGwpEJ/BU5h71sdPWdnuTgZzx4KRlApHZpoPJUYwDQUHYCXCHsbRrgRUTOuzCJ0Z5HAkDRBUJP8duHgtW7heCv2Emb5HfIbQFierkJnaSwjT68B9JNS8z4w6nNUPViXlPn4IN/hmt2YAWts1i+7xQf0laxyZiHvqm2CQyKUpWYg5KrGgLurZdatDAfEcTgxmVB2OzEH9JREn9pW/9wYIB3dJX5Exvbq8y4ptDiTx2q42DRybHVifIKkAKxOE/pvfTIN++7IKXq6G8uWKefrHLDzdyzpXIg+yqN/uWHb0rWRVe6wmI5EwIlL0jdro/3skbw3bSORDIpZaMWZL+F18HhNW9eW7vKGK2heWzehBlUmmwXJiR3C6qmLiv+lBMvgGB/UZ4eA9x5hvVdQ8WQDJnzdjXhnsmd9yS9btGsm4Gqz+WQGYPHs2GsLMfWlY5TAxM/Qn2Q4SDj7/QHjGsGMYQ+RhHchdjEART8Tiae/+SuA0BZxVPO6QDwLPCYVs= root@jd-dev-01"

      package_update: true
      package_upgrade: true
      packages:
        - qemu-guest-agent
        - ca-certificates
        - curl
        - git
        - gnupg
        - jq
        - ripgrep
        - tmux
        - unzip
        - k9s
      runcmd:
        - systemctl enable --now qemu-guest-agent
        - systemctl is-active --quiet qemu-guest-agent
        # Claude Code from Anthropic's signed apt repo, stable channel.
        - install -d -m 0755 /etc/apt/keyrings
        - curl -fsSL https://downloads.claude.ai/keys/claude-code.asc -o /etc/apt/keyrings/claude-code.asc
        # Fail loudly rather than installing from an unexpected key.
        - gpg --show-keys --with-colons /etc/apt/keyrings/claude-code.asc | grep -q '^fpr:::::::::31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE:'
        - echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main" > /etc/apt/sources.list.d/claude-code.list
        - DEBIAN_FRONTEND=noninteractive apt-get update
        - DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confold dist-upgrade
        - DEBIAN_FRONTEND=noninteractive apt-get -y install claude-code
        - DEBIAN_FRONTEND=noninteractive apt-get -y autoremove --purge
    EOF
    file_name = "jd-jump-01.cloud-config.yaml"
  }
}
