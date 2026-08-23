###############################################################################
# Talos image factory schematics
#
# One per CPU vendor: the JD site runs an AMD EPYC 7B13 (Zen 3), the LINDS site
# runs Intel Xeon E5 v4 (Broadwell).
#
# This is a single-tenant homelab running only trusted workloads, so every
# speculative-execution mitigation and kernel hardening feature is turned off
# and the CPUs are pinned to their top P-state. Do not copy this into anything
# that runs untrusted code.
#
# WARNING: the schematic ID is a hash of the rendered YAML, so reordering these
# lists produces a new installer image reference on every node. Append, do not
# reshuffle.
###############################################################################

locals {
  talos_kernel_args_common_head = [
    # ===== Disable ALL CPU vulnerability mitigations =====
    "mitigations=off",
    # Disable split lock detection (avoids #AC perf penalty)
    "split_lock_detect=off",
  ]

  talos_kernel_args_common_mid = [
    # ===== Disable security subsystems =====
    "talos.auditd.disabled=1",
    "init_on_alloc=0",
    "init_on_free=0",
    "security=none",
    "apparmor=0",
    "lsm=",
    "lockdown=none",
    "randomize_kstack_offset=off",

    # ===== Memory/NUMA performance =====
    "transparent_hugepage=madvise",
    "transparent_hugepage_shmem=advise",
    "default_hugepagesz=2M",
    # Multi-gen LRU (MGLRU) - better page reclaim in 6.x
    "lru_gen=Y",
    # Disable memory allocation profiling overhead (6.8+)
    "mem_profiling=off",

    # ===== Scheduler and CPU performance =====
    "idle=nomwait",
    "processor.max_cstate=1",
  ]

  talos_kernel_args_common_clock = [
    "nowatchdog",
    "nmi_watchdog=0",
    "tsc=reliable",
    "clocksource=tsc",
    "hpet=disable",
  ]

  talos_kernel_args_common_gov = [
    "cpufreq.default_governor=performance",

    # ===== Reduce kernel overhead =====
    "audit=0",
    "nomodeset",
    "iommu=pt",
  ]

  talos_kernel_args_common_tail = [
    "raid=noautodetect",
    "cgroup_no_v1=all",
    "rcupdate.rcu_expedited=1",
    "skew_tick=1",
    # RCU lazy callbacks - batches RCU work to reduce IPIs (6.4+)
    "rcutree.enable_rcu_lazy=1",
    # Reduce timer overhead
    "random.trust_cpu=on",
    "random.trust_bootloader=on",
    # Disable kernel memory debugging
    "slub_debug=-",
    "panic=1",
    # VMs should never hibernate
    "nohibernate",

    # ===== Disable kernel page table isolation =====
    "nopti",
  ]

  talos_system_extensions = [
    "siderolabs/crun",
    "siderolabs/iscsi-tools",
    "siderolabs/nfs-utils",
    "siderolabs/nfsd",
    "siderolabs/qemu-guest-agent",
    "siderolabs/util-linux-tools",
  ]

  talos_kernel_args = {
    amd = concat(
      local.talos_kernel_args_common_head,
      local.talos_kernel_args_common_mid,
      local.talos_kernel_args_common_clock,
      # AMD pstate driver (active mode for HW-managed P-states)
      ["amd_pstate=active", "amd_pstate_prefcore=disable"],
      local.talos_kernel_args_common_gov,
      ["amd_iommu=on"],
      local.talos_kernel_args_common_tail,
    )

    intel = concat(
      local.talos_kernel_args_common_head,
      # Re-enable TSX on Broadwell (security off)
      ["tsx=on"],
      local.talos_kernel_args_common_mid,
      ["intel_idle.max_cstate=0"],
      local.talos_kernel_args_common_clock,
      ["intel_pstate=active"],
      local.talos_kernel_args_common_gov,
      ["intel_iommu=on"],
      local.talos_kernel_args_common_tail,
    )
  }
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
