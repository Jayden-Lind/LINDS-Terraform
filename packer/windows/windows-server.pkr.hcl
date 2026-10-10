###############################################################################
# Windows Server template for Proxmox
#
# Installs Windows Server unattended from an ISO already on the node, adds the
# virtio guest tools and the QEMU guest agent, generalises with sysprep and
# leaves a template that guests are cloned from (proxmox/vms-linds.tf).
#
#   packer init .
#   packer build -var-file=packer_linds.pkrvars.hcl .
#
# The machine running Packer needs xorriso (apt install xorriso): Packer builds
# the small CD that carries Autounattend.xml and the first-logon script.
#
# What a clone looks like on first boot: random computer name, DHCP, the local
# Administrator password given here as admin_password, WinRM listening on 5985
# for the addresses in winrm_allowed_sources. Everything after that - name,
# address, domain join, promotion - is Ansible's (LINDS-Ansible,
# playbooks/windows-build.yml).
###############################################################################

packer {
  required_plugins {
    proxmox = {
      version = "~> 1.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

locals {
  # Everything on the answer-file CD. Setup looks for Autounattend.xml in the
  # root of every removable drive; the first-logon command finds bootstrap.ps1
  # the same way.
  unattend_cd = {
    "Autounattend.xml" = templatefile("${path.root}/files/Autounattend.xml.pkrtpl.hcl", {
      admin_password = var.admin_password
      image_name     = var.windows_image_name
      virtio_os_dir  = var.virtio_os_dir
      time_zone      = var.time_zone
    })
    "bootstrap.ps1" = file("${path.root}/files/bootstrap.ps1")
  }
}

source "proxmox-iso" "windows" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  node                     = var.proxmox_node
  insecure_skip_tls_verify = true

  vm_id                = var.template_vm_id
  vm_name              = "packer-${var.template_name}"
  template_name        = var.template_name
  template_description = "${var.windows_image_name}, built by Packer"

  # All three CDs are SATA: Windows Setup reads AHCI without extra drivers,
  # which it cannot do for a virtio-scsi CD before the drivers are loaded.
  boot_iso {
    type     = "sata"
    index    = 0
    iso_file = var.windows_iso_file
    unmount  = true
  }

  additional_iso_files {
    type     = "sata"
    index    = 1
    iso_file = var.virtio_iso_file
    unmount  = true
  }

  additional_iso_files {
    type             = "sata"
    index            = 2
    cd_content       = local.unattend_cd
    cd_label         = "UNATTEND"
    iso_storage_pool = "local"
    unmount          = true
  }

  # UEFI Windows media asks "Press any key to boot from CD or DVD" and gives up
  # after a few seconds.
  boot_wait    = "3s"
  boot_command = ["<spacebar><wait><spacebar><wait><spacebar><wait><spacebar><wait><spacebar><wait><spacebar>"]

  cores      = 4
  sockets    = 1
  cpu_type   = "host"
  memory     = 8192
  os         = "win11"
  bios       = "ovmf"
  machine    = "q35"
  qemu_agent = true

  # A real EFI variable store with Microsoft's keys enrolled, so Secure Boot is
  # on. The older Windows guests here have none, which is why they log a failed
  # Secure Boot update every few hours.
  efi_config {
    efi_storage_pool  = var.proxmox_storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = true
  }

  scsi_controller = "virtio-scsi-single"

  disks {
    type         = "scsi"
    disk_size    = var.disk_size
    storage_pool = var.proxmox_storage_pool
    format       = var.disk_format
    io_thread    = true
    discard      = true
    ssd          = true
  }

  network_adapters {
    bridge   = "vmbr0"
    model    = "virtio"
    vlan_tag = var.build_vlan
    firewall = false
  }

  # WinRM over plain HTTP with Basic authentication, for the build only:
  # bootstrap.ps1 turns it on and seal.ps1 arranges for every clone to turn it
  # off again on first boot.
  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = var.admin_password
  winrm_port     = 5985
  winrm_use_ssl  = false
  winrm_timeout  = "90m"
}

build {
  name    = "windows-server"
  sources = ["source.proxmox-iso.windows"]

  # The guest tools install drivers; clear the pending restart before sysprep,
  # which refuses to run with one outstanding.
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  provisioner "powershell" {
    environment_vars = [
      "CLONE_ADMIN_PASSWORD=${var.admin_password}",
      "CLONE_TIME_ZONE=${var.time_zone}",
      "WINRM_ALLOWED_SOURCES=${var.winrm_allowed_sources}",
    ]
    script = "${path.root}/files/seal.ps1"
  }
}
