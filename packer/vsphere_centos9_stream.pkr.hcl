source "vsphere-iso" "centos9" {
  vcenter_server      = var.vsphere_server
  username            = var.vsphere_user
  password            = var.vsphere_password
  datacenter          = var.datacenter
  host                = var.host
  insecure_connection = true

  vm_name       = "CentOS 9"
  guest_os_type = "centos8_64Guest"

  ssh_username = "jayden"
  ssh_password = var.ssh_password
  firmware     = "efi"

  CPUs            = 4
  RAM             = 4096
  RAM_reserve_all = true

  disk_controller_type = ["pvscsi"]
  datastore            = var.datastore
  storage {
    disk_size             = 16384
    disk_thin_provisioned = true
  }

  cd_files = [
    "./ks.cfg",
  ]

  iso_paths = ["[${var.datastore}] ISO/CentOS-Stream-9.iso"]

  network_adapters {
    network      = var.network_name
    network_card = "vmxnet3"
  }

  boot_command = [
    "<up> e <down><down><end> inst.ks=cdrom:/dev/sr1:/ks.cfg<leftCtrlOn>x<leftCtrlOff><wait>",
  ]
}

build {
  sources = [
    "source.vsphere-iso.centos9"
  ]
}
