variable "nodes" {
  description = "Talos VMs to create, keyed by VM name. Values carry the pinned MAC (Talos nodes get their IP from a DHCP reservation keyed on it)."
  type = map(object({
    mac_address = string
  }))
}

variable "node_name" {
  description = "Proxmox node to place these VMs on."
  type        = string
}

variable "datastore_id" {
  description = "Proxmox datastore for the boot disk."
  type        = string
}

variable "role" {
  description = "Talos role, used for tagging."
  type        = string

  validation {
    condition     = contains(["controlplane", "worker"], var.role)
    error_message = "role must be either controlplane or worker."
  }
}

variable "cores" {
  description = "vCPU cores per node."
  type        = number
}

variable "memory" {
  description = "Dedicated memory per node, in MiB."
  type        = number
}

variable "cpu_flags" {
  description = "QEMU CPU feature flags."
  type        = list(string)
}

variable "disk_size" {
  description = "Boot disk size in GiB."
  type        = number
  default     = 75
}

variable "vlan_id" {
  description = "VLAN tag for the node's single NIC."
  type        = number
}

variable "network_queues" {
  description = "virtio-net multiqueue depth. Should match vCPU count."
  type        = number
}

variable "cdrom_file_id" {
  description = "Talos boot ISO. Only used for the initial install; Talos boots from disk afterwards."
  type        = string
  default     = "local:iso/talos.iso"
}

variable "startup_order" {
  description = "Proxmox boot ordering for the node."
  type        = number
  default     = 8
}
