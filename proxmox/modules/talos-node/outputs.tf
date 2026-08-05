output "vms" {
  description = "The created VMs, keyed by name."
  value       = proxmox_virtual_environment_vm.this
}

output "vm_ids" {
  description = "Proxmox VMIDs, keyed by VM name."
  value       = { for k, v in proxmox_virtual_environment_vm.this : k => v.vm_id }
}
