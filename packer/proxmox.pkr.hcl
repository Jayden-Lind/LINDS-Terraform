source "proxmox-iso" "centos-9" {
  proxmox_url              = var.proxmox_url
  vm_name                  = "packer-centos-9"
  iso_file                 = "local:iso/CentOS-Stream-9.iso"
  iso_checksum             = "none"
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  node                     = var.proxmox_node
  iso_storage_pool         = "local"
  boot_wait                = "10s"
  vm_id                    = "109"
  cloud_init               = true
  cloud_init_storage_pool  = var.proxmox_storage_pool
  boot_command             = ["<up> e <down><down><end> ip=dhcp inst.cmdline inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg<leftCtrlOn>x<leftCtrlOff>"]
  insecure_skip_tls_verify = true
  template_name            = "centos-9"
  template_description     = "packer generated centos-9"
  unmount_iso              = true
  memory                   = 4096
  cores                    = 4
  http_directory           = "."
  cpu_type                 = "host"
  sockets                  = 1
  os                       = "l26"
  qemu_agent               = true
  bios                     = "ovmf"
  ssh_password             = var.ssh_password
  ssh_port                 = 22
  ssh_timeout              = "15m"
  ssh_username             = var.ssh_username
  machine                  = "q35"
  scsi_controller          = "virtio-scsi-single"
  disks {
    type              = "scsi"
    disk_size         = "16G"
    storage_pool      = var.proxmox_storage_pool
    storage_pool_type = "lvm"
    format            = "raw"
    io_thread         = true
  }
  network_adapters {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = false
  }
}

source "proxmox-iso" "ubuntu" {
  proxmox_url              = var.proxmox_url
  vm_name                  = "packer-ubuntu"
  iso_file                 = "local:iso/ubuntu_server.iso"
  iso_checksum             = "none"
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  node                     = var.proxmox_node
  iso_storage_pool         = "local"
  boot_wait                = "10s"
  vm_id                    = "150"
  boot_command             =  [
    "e<wait>",
    "<down><down><down>",
    "<end><bs><bs><bs><bs><wait>",
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10><wait>"
  ]
  insecure_skip_tls_verify = true
  template_name            = "ubuntu"
  template_description     = "packer generated ubuntu"
  unmount_iso              = true
  memory                   = 4096
  cores                    = 4
  http_directory           = "ubuntu"
  cpu_type                 = "host"
  sockets                  = 1
  os                       = "l26"
  qemu_agent               = true
  bios                     = "ovmf"
  ssh_password             = var.ssh_password
  ssh_port                 = 22
  ssh_timeout              = "15m"
  ssh_username             = var.ssh_username
  machine                  = "q35"
  scsi_controller          = "virtio-scsi-single"
  disks {
    type              = "scsi"
    disk_size         = "16G"
    storage_pool      = var.proxmox_storage_pool
    storage_pool_type = "lvm"
    format            = "raw"
    io_thread         = true
  }
  network_adapters {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = false
  }
}

build {
  sources = [
    "source.proxmox-iso.centos-9",
    "source.proxmox-iso.ubuntu"  
  ]
}

variable "ssh_password" {
  type    = string
  default = ""
}

variable "ssh_username" {
  type    = string
  default = ""
}

variable "proxmox_node" {
  type    = string
  default = ""
}

variable "proxmox_url" {
  type    = string
  default = ""
}

variable "proxmox_storage_pool" {
  type    = string
  default = ""
}

variable "proxmox_password" {
  type    = string
  default = ""
}

variable "proxmox_username" {
  type    = string
  default = ""
}

variable "proxmox_storage_format" {
  type    = string
  default = ""
}

variable "proxmox_storage_pool_type" {
  type    = string
  default = ""
}


packer {
  required_plugins {
    name = {
      version = "~> 1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}
