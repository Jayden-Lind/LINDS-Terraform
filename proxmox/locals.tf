locals {
  nodes = {
    jd = {
      name    = "jd-proxmox-02"
      address = "10.0.50.246"
    }
    linds = {
      name    = "linds-proxmox-01"
      address = "192.168.6.205"
    }
  }

  # Ubuntu LTS template built by ../packer. Cloned guests reference it by ID.
  ubuntu_template_vm_id = 150

  # Windows Server 2025 template built by ../packer/windows, with this VMID on
  # each node (packer_linds.pkrvars.hcl and packer_jd.pkrvars.hcl). A clone
  # comes from the template on its own node.
  windows_template_vm_id = 160

  # The CPU of jd-proxmox-02 (EPYC 7B13) has eight groups of eight cores.
  # Each group (CCD) has its own 32 MB L3 cache. A VM that stays on one CCD
  # keeps its data in one cache. Measured on JD-Jump-01 on 2026-11-13:
  # pgbench was 53% faster on one CCD than on all CPUs. The value is the CPU
  # list of one CCD: the eight cores and their second threads.
  #
  # CCD 0: JD-Jump-01, JD-DC-01, JD-Torrent-01. CCD 1: JD-Router-01, which
  # uses the cores 8-15 only (vms-jd-router.tf). CCD 2: talos-cp-01.
  # CCD 3 to 6: talos-worker-01 to 04. CCD 7: JD-FS-01.
  jd_ccd = { for n in range(8) : n => "${n * 8}-${n * 8 + 7},${n * 8 + 64}-${n * 8 + 71}" }

  # linds-proxmox-01 has two CPU sockets (2 x Xeon E5-2640 v4). Each socket is
  # one NUMA node with its own memory: node 0 has the even CPU numbers, node 1
  # the odd ones. A VM that can use all CPUs gets memory from both nodes, and
  # the kernel then moves pages between the nodes all the time (4.9 thousand
  # million pages in 39 days, read on 2026-11-18). A VM that stays on one node
  # keeps its memory there. The value is the CPU list of one node.
  #
  # Node 0 (the NICs are there): LINDS-Router-01, LINDS-Torrent-02, the two
  # Talos workers. Node 1: LINDS-Truenas-01, LINDS-DC, LINDS-DC2,
  # LINDS-Plex-01. That is 46 and 48 GiB of the 64 GiB of each node.
  linds_numa = {
    0 = join(",", range(0, 40, 2))
    1 = join(",", range(1, 40, 2))
  }

  # Default guest datastores per site.
  datastores = {
    jd    = "ssd-mixed" # ZFS raidz1 on VM pool
    linds = "local-lvm"
  }

  # Speculative-execution mitigations are disabled cluster-wide: this is a
  # single-tenant homelab and the guests are all trusted, so the ~15-30% syscall
  # tax is not worth paying. +pdpe1gb exposes 1 GiB pages, +aes exposes AES-NI.
  #
  # +pcid: PCID is not a mitigation, and hiding it buys nothing. It tags TLB
  # entries per address space so a context switch does not have to flush
  # them. It sits in Proxmox's flag list next to the mitigation bits because
  # it made Meltdown's page-table isolation cheaper, and it was switched off
  # with them until 2026-11. Linux and Windows use it with PTI on or off, and
  # a TLB refill in a guest is the expensive kind (a two-dimensional walk
  # through NPT/EPT). Both hosts have it (Zen 3 and Broadwell) and KVM on
  # both offers it to guests.
  #
  # A CPU flag is read when QEMU starts. `terraform apply` leaves it pending
  # and a reboot from inside the guest (talosctl reboot/upgrade) does not pick
  # it up; `qm reboot <vmid>` or a stop/start does. See README.
  #
  # JD-Torrent-01 and JD-Jump-01 do not set reboot_after_update = false, so
  # the provider restarts them when this list changes - and JD-Jump-01 is
  # where Terraform runs. Before you change the list, put the new value on
  # those VMs as a pending change (`qm set <vmid> --cpu ...`). The provider
  # reads the pending value and then has nothing to apply.
  guest_cpu_flags = [
    "-md-clear",
    "+pcid",
    "-spec-ctrl",
    "-ssbd",
    "-ibpb",
    "-virt-ssbd",
    "-amd-ssbd",
    "-amd-no-ssb",
    "+pdpe1gb",
    "-hv-tlbflush",
    "-hv-evmcs",
    "+aes",
  ]
}
