###############################################################################
# Ubuntu LTS template for Proxmox
#
# One build, one template. Everything that differs between sites or between LTS
# releases is a variable, so bumping to the next LTS is a version + checksum
# change rather than a new copy of this file.
#
#   packer init .
#   packer build -var-file=packer_jd.pkrvars.hcl .
#
# The resulting template is what proxmox/locals.tf's ubuntu_template_vm_id
# points at; guests clone from it via cloud-init.
###############################################################################

packer {
  required_plugins {
    proxmox = {
      version = "~> 1.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "ubuntu" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  node                     = var.proxmox_node
  insecure_skip_tls_verify = true

  vm_id                = var.template_vm_id
  vm_name              = "packer-${var.template_name}"
  template_name        = var.template_name
  template_description = "Ubuntu ${var.ubuntu_version} LTS, built by Packer"

  # Fetched and cached by Proxmox itself rather than assuming someone has
  # already dropped the ISO into local:iso by hand.
  boot_iso {
    type             = "scsi"
    iso_url          = var.iso_url
    iso_checksum     = var.iso_checksum
    iso_storage_pool = "local"
    unmount          = true
  }

  # Interrupt GRUB and point the installer at the autoinstall config Packer
  # serves out of ./http.
  boot_wait    = "10s"
  boot_command = ["e<wait><down><down><down><end> autoinstall 'ds=nocloud;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/'<F10>"]

  http_directory = "http"

  cores      = 4
  sockets    = 1
  cpu_type   = "host"
  memory     = 4096
  os         = "l26"
  bios       = "ovmf"
  machine    = "q35"
  qemu_agent = true

  # Deliberately no efi_config: the existing template has no efidisk0, and
  # adding one would show up as drift on every guest cloned from it, since the
  # Terraform VM definitions do not declare an efi_disk block either.

  scsi_controller = "virtio-scsi-single"

  disks {
    type         = "scsi"
    disk_size    = var.disk_size
    storage_pool = var.proxmox_storage_pool
    format       = var.disk_format
    io_thread    = true
  }

  network_adapters {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = false
  }

  # Credentials come from the autoinstall user-data in ./http.
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_port     = 22
  ssh_timeout  = "30m"
}

build {
  name    = "ubuntu-lts"
  sources = ["source.proxmox-iso.ubuntu"]

  # cloud-init must come up clean on every clone, so strip the identity the
  # build itself picked up.
  provisioner "shell" {
    execute_command = "sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
    inline = [
      "cloud-init status --wait || true",
      "cloud-init clean --logs --machine-id",
      "rm -f /etc/netplan/50-cloud-init.yaml",
      "truncate -s 0 /etc/machine-id",
      "rm -f /var/lib/dbus/machine-id",
      "apt-get -y autoremove --purge",
      "apt-get -y clean",
      "rm -rf /var/lib/apt/lists/*",
      "rm -f /etc/ssh/ssh_host_*",
      "truncate -s 0 /var/log/wtmp /var/log/lastlog",
    ]
  }
}
