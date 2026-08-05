###############################################################################
# NFS exports on jd-proxmox-02
#
# Scope is deliberately narrow: this manages /etc/exports and nothing else.
#
# ZFS pools, datasets and their properties are NOT managed by Terraform. They
# hold live data, they were built by hand, and there is no provider that can
# touch them safely - a reconciler with `zfs create` and `zfs set` in it is far
# more blast radius than the problem deserves. The current layout is documented
# in README.md for reference only; change it with `zfs` on the host.
#
# The exports below replace the shares that used to live on the jd-truenas-01
# VM before the 2026-05-24 migration.
###############################################################################

locals {
  nfs_exports = {
    "/mnt/NAS" = {
      # VM/truenas-nas. General-purpose share: LAN, k8s storage VLAN, the LINDS
      # site across the tunnel, and the torrent VLAN.
      clients = ["10.0.50.0/24", "10.0.53.0/24", "10.3.1.0/24", "10.0.36.0/24"]
      options = "sec=sys,rw,no_root_squash,insecure,no_subtree_check"
    }

    "/mnt/HDD" = {
      # HDD-20T/data. Bulk media; everything is squashed to root rather than
      # trying to keep uids consistent across clients.
      clients = ["10.0.53.0/24", "10.0.50.0/24"]
      options = "sec=sys,rw,anonuid=0,anongid=0,all_squash,insecure,no_subtree_check"
    }
  }

  nfs_exports_content = join("\n", concat(
    ["# Managed by Terraform (proxmox/nfs.tf). Manual edits will be overwritten."],
    [
      for path in sort(keys(local.nfs_exports)) :
      "${path}  ${join(" ", [for c in local.nfs_exports[path].clients : "${c}(${local.nfs_exports[path].options})"])}"
    ],
  ))

  nfs_reconcile_script = templatefile("${path.module}/templates/nfs-exports.sh.tftpl", {
    exports = local.nfs_exports_content
  })
}

resource "null_resource" "nfs_exports" {
  count = var.manage_nfs_exports ? 1 : 0

  triggers = {
    exports = sha256(local.nfs_exports_content)
  }

  connection {
    type        = "ssh"
    host        = local.nodes.jd.address
    user        = var.proxmox_ssh_username
    password    = var.proxmox_ssh_private_key != null ? null : var.proxmox_ssh_password
    private_key = var.proxmox_ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [local.nfs_reconcile_script]
  }
}
