# Adopted on 2026-11-07: guests that were made by hand or by Packer. The
# resources are in guests-adopted.tf. Import changes nothing on the hosts.

import {
  to = proxmox_virtual_environment_vm.jd_ubuntu_template
  id = "jd-proxmox-02/150"
}

import {
  to = proxmox_virtual_environment_vm.jd_windows_template
  id = "jd-proxmox-02/160"
}

import {
  to = proxmox_virtual_environment_vm.jd_backup
  id = "jd-proxmox-02/1115"
}

import {
  to = proxmox_virtual_environment_vm.linds_truenas
  id = "linds-proxmox-01/103"
}

import {
  to = proxmox_virtual_environment_vm.linds_dc_old
  id = "linds-proxmox-01/102"
}

import {
  to = proxmox_virtual_environment_vm.linds_backup_old
  id = "linds-proxmox-01/104"
}

import {
  to = proxmox_virtual_environment_vm.linds_dc2_old
  id = "linds-proxmox-01/110"
}

import {
  to = proxmox_virtual_environment_vm.linds_centos_template
  id = "linds-proxmox-01/109"
}

import {
  to = proxmox_virtual_environment_vm.linds_ubuntu_template
  id = "linds-proxmox-01/150"
}

import {
  to = proxmox_virtual_environment_vm.linds_ubuntu26_template
  id = "linds-proxmox-01/151"
}

import {
  to = proxmox_virtual_environment_vm.linds_windows_template
  id = "linds-proxmox-01/160"
}
