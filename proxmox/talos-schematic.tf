###############################################################################
# Talos image factory schematics
#
# Keyed by CPU vendor: the JD site runs an AMD EPYC 7B13 (Zen 3), the LINDS
# site runs Intel Xeon E5-2640 v4 (Broadwell).
#
# Every Talos node is a KVM guest on one of those hosts, and that decides what
# belongs on the kernel command line. A guest has no cpufreq driver, no
# cpuidle driver and no IOMMU (cpuidle/current_driver reads "none", there is
# no cpufreq directory), so P-states, C-states and DMA remapping are set on
# the Proxmox hosts and nowhere else. The vendor-specific arguments this file
# used to carry - amd_pstate, intel_pstate, intel_idle.max_cstate, amd_iommu,
# intel_iommu, tsx - each addressed something that declines to bind or does
# not exist in the guest. Both vendors therefore get the same list and, the
# schematic ID being a content hash, the same image. The two keys stay so an
# argument that really does differ per host has somewhere to go.
#
# What the CPU vendor does decide is which instructions the guest may use.
# That comes from the VM's CPU type and flags (locals.tf), not from here.
#
# This is a single-tenant homelab running only trusted workloads, so the
# speculative-execution mitigations are off, and so is every kernel hardening
# feature that has a runtime cost and a command-line switch. Do not copy this
# into anything that runs untrusted code.
#
# Check a change on a booted node before trusting it. The kernel logs what it
# did not recognise, and eleven of the arguments that used to be here were in
# that output:
#   talosctl dmesg | grep -iE 'unknown kernel command|malformed|unknown option'
# A clean result is necessary, not sufficient: a dotted parameter for something
# that is not built (rcutree.enable_rcu_lazy was one) is never reported, and a
# parameter for a driver that does not bind is accepted without complaint. For
# those, look at what the driver says, or at sysfs.
#
# WARNING: the schematic ID is a hash of the rendered YAML, so reordering this
# list produces a new installer image reference on every node. Append, do not
# reshuffle.
###############################################################################

locals {
  talos_kernel_args_guest = [
    # ===== CPU vulnerability mitigations =====
    # nopti is not redundant - do not drop it. Talos boots every node with
    # pti=on, which forces page-table isolation on even on the AMD nodes,
    # where Meltdown does not apply. On this kernel (6.18) mitigations=off
    # only turns PTI off when the mode was left on auto, so it does not
    # override that. nopti does, because it comes later on the command line.
    "mitigations=off",
    "nopti",

    # ===== Kernel hardening with a runtime cost =====
    "init_on_alloc=0",
    "init_on_free=0",
    "randomize_kstack_offset=off",
    # Bounds check on every copy to and from user space, so on every send and
    # recv. Default on in the Talos kernel (HARDENED_USERCOPY_DEFAULT_ON).
    "hardened_usercopy=off",
    "slub_debug=-",

    # ===== Security modules and audit =====
    # security=none drops SELinux and AppArmor. yama, safesetid, bpf and
    # landlock stay registered: the only switch for those is lsm=, and an
    # empty lsm= reaches the kernel as a bare "lsm", which it discards.
    "security=none",
    "apparmor=0",
    "audit=0",
    "talos.auditd.disabled=1",

    # ===== Memory =====
    # MGLRU needs nothing here: the Talos kernel builds it default-on.
    "transparent_hugepage=madvise",
    "transparent_hugepage_shmem=advise",
    "default_hugepagesz=2M",

    # ===== Clock =====
    # A guest defaults to kvm-clock. QEMU does not advertise an invariant TSC
    # (no constant_tsc or nonstop_tsc in the guest's CPU flags), so the kernel
    # has to be told the TSC is trustworthy before it will stay on it.
    "tsc=reliable",
    "clocksource=tsc",

    # ===== RCU and timer tick =====
    "rcupdate.rcu_expedited=1",
    "skew_tick=1",

    # ===== Boot =====
    "nomodeset",
    "raid=noautodetect",
    "cgroup_no_v1=all",
    "random.trust_cpu=on",
    "random.trust_bootloader=on",
    # Covers early boot only: once Talos is up it sets kernel.panic to 10.
    "panic=1",
  ]

  talos_kernel_args = {
    amd   = local.talos_kernel_args_guest
    intel = local.talos_kernel_args_guest
  }

  talos_system_extensions = [
    "siderolabs/crun",
    "siderolabs/iscsi-tools",
    "siderolabs/nfs-utils",
    "siderolabs/nfsd",
    "siderolabs/qemu-guest-agent",
    "siderolabs/util-linux-tools",
  ]
}

resource "talos_image_factory_schematic" "this" {
  for_each = local.talos_kernel_args

  schematic = yamlencode({
    customization = {
      extraKernelArgs = each.value
      systemExtensions = {
        officialExtensions = local.talos_system_extensions
      }
    }
  })
}

###############################################################################
# Boot ISOs, pulled from the image factory onto each site's local ISO store.
#
# The filename carries the Talos version, so bumping local.talos_version
# downloads the matching ISO and repoints every node's cdrom at it - no more
# hand-managed talos.iso going stale. That staleness is not hypothetical: the
# original talos.iso was v1.11.6, and its maintenance-mode Talos rejected the
# v1.13-generation machine config (unknown key machine.install.grubUseUKICmdline)
# when talos-worker-04 was added.
#
# These must be the factory schematic images, not the vanilla GitHub release
# ISOs: maintenance mode then boots with the same kernel args and extensions
# the installed system gets.
###############################################################################

resource "proxmox_virtual_environment_download_file" "talos_iso_jd" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = local.nodes.jd.name
  file_name    = "talos-${local.talos_version}-amd.iso"
  url          = "https://factory.talos.dev/image/${talos_image_factory_schematic.this["amd"].id}/${local.talos_version}/metal-amd64.iso"
}

resource "proxmox_virtual_environment_download_file" "talos_iso_linds" {
  provider = proxmox.linds

  content_type = "iso"
  datastore_id = "local"
  node_name    = local.nodes.linds.name
  file_name    = "talos-${local.talos_version}-intel.iso"
  url          = "https://factory.talos.dev/image/${talos_image_factory_schematic.this["intel"].id}/${local.talos_version}/metal-amd64.iso"
}
