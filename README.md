# LINDS-Terraform

![terraform](img/tf.png)

## Intro

Uses [vSphere terraform provider](https://registry.terraform.io/providers/hashicorp/vsphere/2.2.0) to provision VM's, Host Port Groups, Datastore.

For Proxmox I use [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest)

[Packer](https://www.packer.io/) to create the VM template of CentOS images, which is then cloned per ESXi host and Proxmox host.

## Packer

### Vsphere

1. Change to packer directory

```shell
$ cd packer/
```

2. Fill in `packer/vars.auto.pkrvars.hcl.example` and rename it to `packer/vars.auto.pkrvars.hcl`.

Example:
```
vsphere_server   = "jd-vsca-01.linds.com.au"
vsphere_user     = "administrator@vsphere.local"
vsphere_password = "xxxxxxxxxx"
datacenter       = "LINDS"
datastore        = "JD-Datastore-OS"
network_name     = "Native VLAN"
host             = "jd-esxi-01.linds.com.au"
ssh_password     = "xxxxxxxxxx"
```

3. In the designated datastore, copy [CentOS 9 Stream ISO](https://mirrors.centos.org/mirrorlist?path=/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-dvd1.iso&redirect=1&protocol=https) to `<datastore>/ISO/CentOS-Stream-9.iso` and [CentOS 8 Stream ISO](http://isoredirect.centos.org/centos/8-stream/isos/x86_64/) to `<datastore>/ISO/CentOS-Stream-8.iso`

4. Run the below command to build and provision both CentOS 9 and CentOS 8.

```shell
$ cd packer/
$ packer build -force .
```

**To build only CentOS 8:**

```shell
$ packer build -var-file=vars.auto.pkrvars.hcl -only=vsphere-iso.centos8 -force .
```

**To build only CentOS 9:**

```shell
$ packer build -var-file=vars.auto.pkrvars.hcl -only=vsphere-iso.centos9 -force .
```

### Proxmox


**To build CentOS 9 on proxmox**

1. Copy and rename variables-proxmox.pkrvars.hcl.example to variables-proxmox.pkrvars.hcl and fill in variables

2. Run the below command
```shell
cd packer && packer build -var-file=packer_jd.pkrvars.hcl -only=proxmox-iso.centos-9 -force . 
```

**To build Ubuntu Server 2024 on proxmox**

1. Run the below command
```shell
cd packer && packer build -var-file=packer_jd.pkrvars.hcl -only=proxmox-iso.ubuntu -force .
```

## Terraform

### vSphere

1. Copy and rename [terraform.tfvars.example](/terraform.tfvars.example)

Example:
```
vsphere_server      = "xxxx"
vsphere_user        = "xxxx"
vsphere_password    = "xxxx"
datacenter          = "xxxx"
jd-datastore        = "xxxx"
jd-host             = "xxxx"
linds-host          = "xxxx"
linds-datastore     = "xxxx"
jd_network_name     = "xxxxxxx"
jd_centos_9         = "CentOS 9"
jd_centos_8         = "CentOS 8"
linds_centos_9      = "CentOS 9-LINDS"
linds_centos_8      = "CentOS 8-LINDS"
host_licensekey     = "xxxxx-xxxxx-xxxxx-xxxxx-xxxxx"
```

2. Initialise Terraform and apply configuration

```shell
$ terraform init

$ terraform plan

$ terraform apply
```
#### State

State is kept on TrueNAS NFS share, that is then rsync'd to secondary TrueNAS offsite. This can be seen in [versions.tf](/versions.tf).

### Proxmox

1. Switch to proxmox directory

`cd proxmox/`

2. Copy and rename [terraform.tfvars.example](/proxmox/terraform.tfvars.example)

3. Copy and rename [backend.conf.example](/proxmox/backend.conf.example) to `backend.conf` and fill in your MinIO/S3 credentials.

4. Initialise Terraform and apply configuration

```shell
$ terraform init -backend-config=backend.conf
$ terraform plan -var-file proxmox_jd_terraform.tfvars
$ terraform plan -var-file proxmox_linds_terraform.tfvars
```


### Talos
terraform destroy -var-file=proxmox_jd_terraform.tfvars -target=proxmox_virtual_environment_vm.talos_cp -target=proxmox_virtual_environment_vm.talos_worker

run it twice, reboot nodes after second run