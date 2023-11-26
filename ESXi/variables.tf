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

variable "jd-username" {
  description = "ESXi Host Username"
  type        = string
}

variable "jd-password" {
  description = "ESXi Host Password"
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

variable "jd_centos_9" {
  description = "CentOS 9 name (ie: image_path)"
  type        = string
}

variable "jd_centos_8" {
  description = "CentOS 8 name (ie: image_path)"
  type        = string
}

variable "linds_centos_9" {
  description = "CentOS 9 name (ie: image_path)"
  type        = string
}

variable "linds_centos_8" {
  description = "CentOS 8 name (ie: image_path)"
  type        = string
}

variable "host_licensekey" {
  description = "ESXi Host license key"
  type        = string
}
