output "talosconfig" {
  description = "talosctl client configuration for the cluster."
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "kubeconfig" {
  description = "Admin kubeconfig for the cluster."
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "talos_installer_images" {
  description = "Installer image reference per CPU vendor. Bump local.talos_version to upgrade."
  value = {
    for k, s in talos_image_factory_schematic.this :
    k => "factory.talos.dev/installer/${s.id}:${local.talos_version}"
  }
}

output "vm_ids" {
  description = "Proxmox VMIDs of every guest managed by this module."
  value = merge(
    module.talos_cp_jd.vm_ids,
    module.talos_workers_jd.vm_ids,
    module.talos_workers_linds.vm_ids,
    {
      (proxmox_virtual_environment_vm.jd_torrent.name)    = proxmox_virtual_environment_vm.jd_torrent.vm_id
      (proxmox_virtual_environment_vm.jd_dc.name)         = proxmox_virtual_environment_vm.jd_dc.vm_id
      (proxmox_virtual_environment_vm.jd_minecraft.name)  = proxmox_virtual_environment_vm.jd_minecraft.vm_id
      (proxmox_virtual_environment_vm.jd_dev.name)        = proxmox_virtual_environment_vm.jd_dev.vm_id
      (proxmox_virtual_environment_vm.linds_plex.name)    = proxmox_virtual_environment_vm.linds_plex.vm_id
      (proxmox_virtual_environment_vm.linds_torrent.name) = proxmox_virtual_environment_vm.linds_torrent.vm_id
      (proxmox_virtual_environment_vm.linds_dc2.name)     = proxmox_virtual_environment_vm.linds_dc2.vm_id
      (proxmox_virtual_environment_vm.linds_dc.name)      = proxmox_virtual_environment_vm.linds_dc.vm_id
      (proxmox_virtual_environment_vm.jd_fs_01.name)      = proxmox_virtual_environment_vm.jd_fs_01.vm_id
    },
  )
}

output "windows_bootstrap_addresses" {
  description = "IPv4 addresses the Windows guests report through the guest agent. A fresh clone is on DHCP; Ansible needs this address for its first connection (LINDS-Ansible, playbooks/windows-prepare.yml, -e bootstrap_address=...)."
  value = {
    (proxmox_virtual_environment_vm.linds_dc2.name) = [
      for address in flatten(proxmox_virtual_environment_vm.linds_dc2.ipv4_addresses) : address
      if !startswith(address, "127.") && !startswith(address, "169.254.")
    ]
    (proxmox_virtual_environment_vm.linds_dc.name) = [
      for address in flatten(proxmox_virtual_environment_vm.linds_dc.ipv4_addresses) : address
      if !startswith(address, "127.") && !startswith(address, "169.254.")
    ]
    (proxmox_virtual_environment_vm.jd_fs_01.name) = [
      for address in flatten(proxmox_virtual_environment_vm.jd_fs_01.ipv4_addresses) : address
      if !startswith(address, "127.") && !startswith(address, "169.254.")
    ]
  }
}
