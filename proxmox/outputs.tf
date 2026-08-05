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
    },
  )
}
