# LINDS-Terraform

![terraform](img/tf.png)

## Intro

Uses [vSphere terraform provider](https://registry.terraform.io/providers/hashicorp/vsphere/2.2.0) to provision VM's, Host Port Groups, Datastore.

[Packer](https://www.packer.io/) to create the VM template of CentOS 9 Stream image, which is then cloned per ESXi host.


### Packer Usage

Packer is creating a [CentOS 9 Stream](https://centos.org/stream9/) image, that installs and enables Puppet, then making CentOS 9 Stream a template on the local ESXi host. On boot up of cloning the template VM will automatically register with Puppet and start provisioning based on [LINDS-Puppet](https://github.com/Jayden-Lind/LINDS-Puppet).

1. Change to packer directory

```shell
cd packer
```

2. Create `vars.auto.pkvars.hcl`

3. Fill in the variables defined in [packer/variables.pkr.hcl](packer/variables.pkr.hcl) to `vars.auto.pkvars.hcl`

4. In the designated datastore, copy over CentOS 9 Stream [ISO](https://mirrors.centos.org/mirrorlist?path=/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-dvd1.iso&redirect=1&protocol=https) to `<datastore>/ISO/CentOS-Stream-9.iso`

5. Run the below command to build and provision a CentOS 9 Stream template.

```shell
packer build -force .
```


### Terraform Usage

1. Create `terraform.tfvars`, and fill in the variable values, that are specified in [variables.tf](/variables.tf)

EG: 

`vsphere_server = "jd-vsca-01.linds.com.au"`

2. Initialise Terraform and apply configuration

```console
$ terraform init

$ terraform apply
```
## State

State is kept on TrueNAS NFS share, that is then rsync'd to secondary TrueNAS offsite. This can be seen in [versions.tf](/versions.tf).