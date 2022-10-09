variable "vsphere_server" {
  description = "vSphere server"
  type        = string
}

variable "vsphere_user" {
  description = "vSphere username"
  type        = string
}

variable "vsphere_password" {
  description = "vSphere password"
  type        = string
  sensitive   = true
}

variable "datacenter" {
  description = "vSphere data center"
  type        = string
}

variable "jd-host" {
  description = "vSphere host"
  type        = string
}

variable "linds-host" {
  description = "vSphere host"
  type        = string
}

variable "jd-datastore" {
  description = "vSphere datastore"
  type        = string
}

variable "linds-datastore" {
  description = "vSphere datastore"
  type        = string
}

variable "jd_network_name" {
  description = "vSphere network name"
  type        = string
}

variable "jd_template_name" {
  description = "CentOS name (ie: image_path)"
  type        = string
}

variable "linds_template_name" {
  description = "CentOS name (ie: image_path)"
  type        = string
}

variable "host_licensekey" {
  description = "ESXi Host license key"
  type        = string
}