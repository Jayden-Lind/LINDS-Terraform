###############################################################################
# Talos cluster configuration
#
# Single control plane at 10.0.53.200, four workers at .201-.204 on the JD
# site, two workers at 10.3.1.100-101 on the LINDS site. Scheduling is allowed
# on the control plane.
###############################################################################

locals {
  # Upgrade order: bump talos_version, `terraform apply` (machine config only -
  # nothing reboots), then `talosctl upgrade` node by node with the installer
  # image from `terraform output talos_installer_images`. Only after every node
  # runs the new Talos bump kubernetes_version and apply again - control plane
  # first (-target the controlplane apply), then the workers.
  #
  # That wait is for a Kubernetes *minor* the running Talos does not support
  # yet. A patch release of the current minor (v1.37.0 -> v1.37.1 here) can go
  # in the same apply as the Talos bump; the control plane still goes first.
  talos_version      = "v1.14.2"
  kubernetes_version = "v1.37.1"

  # Version contract the machine config is *generated* against - which schema
  # and defaults the provider emits. It is not the installed Talos version and
  # does not follow talos_version above.
  #
  # Left unset it tracks the Talos SDK bundled in the provider, so a provider
  # upgrade silently regenerates every node's config. Under the v1.14 contract
  # the base config is split into per-feature documents (UnattendedInstallConfig,
  # KubeletConfig, ResolverConfig, DiscoveryServiceConfig, ...). Those are
  # mutually exclusive with the v1alpha1 fields patched in below, and they
  # default the public discovery service and forwardKubeDNSToHost back on -
  # both switched off here on purpose.
  #
  # v1.13 is what provider 0.11 was emitting, and provider 0.12 pinned to it
  # renders byte-identical configs for all three node classes. Raise it only
  # together with a migration of the patches to the new documents.
  talos_config_contract = "v1.13"

  cluster_name     = "talos-cluster"
  cluster_endpoint = "https://10.0.53.200:6443"

  controlplane_node = "10.0.53.200"
  worker_nodes_jd   = [for i in range(4) : "10.0.53.${201 + i}"]
  worker_nodes_lind = [for i in range(2) : "10.3.1.${100 + i}"]

  talos_common_config = {
    machine = {
      install = {
        disk  = "/dev/sda"
        image = "factory.talos.dev/installer/${talos_image_factory_schematic.this["amd"].id}:${local.talos_version}"
      }
      kubelet = {
        image = "ghcr.io/siderolabs/kubelet:${local.kubernetes_version}-fat"
        extraConfig = {
          # Pull images in parallel instead of one at a time per node; a
          # drained node coming back was serialising 15+ pulls.
          serializeImagePulls   = false
          maxParallelImagePulls = 5
        }
      }
      # Declarative replacement for the old node_labels local-exec hack.
      # LINDS workers override both labels to linds below.
      #
      # topology.kubernetes.io/zone is what Kubernetes topology-aware routing
      # (Service.spec.trafficDistribution) and Cilium's serviceTopology key on;
      # `datacenter` stays as the label the existing nodeSelectors and spread
      # constraints in LINDS-Kubernetes use. Same value, two consumers.
      nodeLabels = {
        datacenter                    = "jd"
        "topology.kubernetes.io/zone" = "jd"
      }
      features = {
        hostDNS = {
          enabled = true
          # CoreDNS forwards straight to the upstream DNS servers now
          # (base/coredns.yml in LINDS-Kubernetes): the 169.254.116.108
          # hostDNS hop dropped queries under Cilium socketLB.
          forwardKubeDNSToHost = false
        }
        kubePrism = {
          enabled = true
          port    = 7445
        }
      }
      sysctls = {
        # fq, to agree with Cilium. Its bandwidth manager needs fq under BBR
        # and EDT pacing and writes this sysctl itself when the agent starts,
        # so the "noqueue" that used to be here was never the live value -
        # Talos reported one thing and the kernel ran another. noqueue was
        # also wrong on its own terms: on a NIC it means packets are dropped,
        # not queued, whenever the virtio TX ring is full.
        "net.core.default_qdisc" = "fq"
        # Talos sets 2 (a KSPP default): constant blinding for every BPF
        # program, root's included. That rewrites each immediate in Cilium's
        # datapath into extra instructions, and a blinded program cannot have
        # its tail calls patched into direct jumps, which Cilium makes several
        # of per packet. 1 blinds unprivileged loaders only, and unprivileged
        # BPF stays disabled, so nothing is given up. Talos logs "overriding
        # KSPP enforced parameter" at boot; that is this line. Programs pick it
        # up when they are next loaded, i.e. on the next agent restart.
        "net.core.bpf_jit_harden" = "1"

        # net.ipv4.tcp_rmem is deliberately absent from the list below. The
        # "4096 87380 16777216" that used to be set is lower than what this
        # kernel picks for itself (4096 131072 33554432).
        "net.core.somaxconn"              = "65535"
        "net.core.netdev_max_backlog"     = "65535"
        "net.core.rmem_max"               = "16777216"
        "net.core.wmem_max"               = "16777216"
        "net.core.busy_poll"              = "50"
        "net.core.busy_read"              = "50"
        "net.ipv4.tcp_wmem"               = "4096 65536 16777216"
        "net.ipv4.tcp_max_syn_backlog"    = "65535"
        "net.ipv4.tcp_tw_reuse"           = "1"
        "net.ipv4.ip_local_port_range"    = "10240 65535"
        "net.ipv4.tcp_fin_timeout"        = "15"
        "net.ipv4.tcp_keepalive_time"     = "600"
        "net.ipv4.tcp_keepalive_intvl"    = "30"
        "net.ipv4.tcp_keepalive_probes"   = "10"
        "net.ipv4.tcp_congestion_control" = "bbr"
        "net.ipv4.tcp_fastopen"           = "3"
        "net.netfilter.nf_conntrack_max"  = "1048576"
        "fs.inotify.max_user_watches"     = "1048576"
        "fs.inotify.max_user_instances"   = "8192"
        "fs.file-max"                     = "2097152"
        "vm.max_map_count"                = "262144"
        "vm.compaction_proactiveness"     = "0"
        "vm.zone_reclaim_mode"            = "0"
        "vm.page_lock_unfairness"         = "1"
      }
      network = {
        interfaces = [
          {
            interface = "lo"
            addresses = ["169.254.116.108/32"]
          }
        ]
      }
      time = {
        servers = [
          "time.cloudflare.com",
          "pool.ntp.org"
        ]
      }
    }

    cluster = {
      network = {
        cni = {
          name = "none"
        }
      }
      proxy = {
        disabled = true
      }
      # No KubeSpan and a single cluster: the public discovery service is
      # unused and was just logging "discovery.talos.dev unreachable" noise.
      discovery = {
        enabled = false
      }
    }
  }

  # LINDS nodes are Intel Broadwell. The label differs; the schematic is keyed
  # separately but currently renders the same image (see talos-schematic.tf).
  talos_common_config_linds = merge(local.talos_common_config, {
    machine = merge(local.talos_common_config.machine, {
      install = {
        disk  = "/dev/sda"
        image = "factory.talos.dev/installer/${talos_image_factory_schematic.this["intel"].id}:${local.talos_version}"
      }
      nodeLabels = {
        datacenter                    = "linds"
        "topology.kubernetes.io/zone" = "linds"
      }
    })
  })

  talos_cp_config = {
    cluster = {
      allowSchedulingOnControlPlanes = true
      apiServer = {
        admissionControl = [
          {
            name = "PodSecurity"
            configuration = {
              # v1 has been GA since Kubernetes 1.25; the alpha version was
              # only still accepted, not documented.
              apiVersion = "pod-security.admission.config.k8s.io/v1"
              # Nothing is enforced (the CSI drivers, Zabbix agent, Cilium
              # and Home Assistant all need privileged/hostNetwork), but
              # warn+audit at baseline surfaces which workloads would fail a
              # future baseline enforcement instead of hiding it.
              defaults = {
                audit             = "baseline"
                "audit-version"   = "latest"
                enforce           = "privileged"
                "enforce-version" = "latest"
                warn              = "baseline"
                "warn-version"    = "latest"
              }
              exemptions = {
                namespaces     = []
                runtimeClasses = []
                usernames      = []
              }
              kind = "PodSecurityConfiguration"
            }
          }
        ]
      }
    }
  }
}

resource "talos_machine_secrets" "this" {
}

# kubernetes_version pins the control plane static pod images (apiserver,
# controller-manager, scheduler). Without it the provider falls back to whatever
# it was built against, which is how the static pods ended up on v1.36.0 while
# the kubelets ran the v1.36.1 set by machine.kubelet.image above.
data "talos_machine_configuration" "controlplane" {
  cluster_name       = local.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = local.kubernetes_version
  talos_version      = local.talos_config_contract
}

data "talos_machine_configuration" "worker" {
  cluster_name       = local.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = local.kubernetes_version
  talos_version      = local.talos_config_contract
}

data "talos_client_configuration" "this" {
  cluster_name         = local.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration

  endpoints = [local.controlplane_node]

  nodes = concat(
    [local.controlplane_node],
    local.worker_nodes_jd,
    local.worker_nodes_lind,
  )
}

# apply_mode = no_reboot on all three: the provider's default "auto" reboots a
# node on the spot if a config change needs it, which on a plain `terraform
# apply` would reboot every node at once. Fail instead, and stage such a change
# deliberately.
resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = local.controlplane_node
  apply_mode                  = "no_reboot"

  config_patches = [
    yamlencode(local.talos_common_config),
    yamlencode(local.talos_cp_config)
  ]

  depends_on = [module.talos_cp_jd]
}

resource "talos_machine_configuration_apply" "worker" {
  count = length(local.worker_nodes_jd)

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = local.worker_nodes_jd[count.index]
  apply_mode                  = "no_reboot"

  config_patches = [yamlencode(local.talos_common_config)]

  depends_on = [module.talos_workers_jd]
}

resource "talos_machine_configuration_apply" "worker_linds" {
  count = length(local.worker_nodes_lind)

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = local.worker_nodes_lind[count.index]
  apply_mode                  = "no_reboot"

  config_patches = [yamlencode(local.talos_common_config_linds)]

  depends_on = [module.talos_workers_linds]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.controlplane_node

  depends_on = [talos_machine_configuration_apply.controlplane]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.controlplane_node

  depends_on = [talos_machine_bootstrap.this]
}

resource "local_file" "talosconfig" {
  filename        = "${path.module}/talosconfig"
  content         = data.talos_client_configuration.this.talos_config
  file_permission = "0600"
}

resource "local_file" "kubeconfig" {
  filename        = "${path.module}/kubeconfig"
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  file_permission = "0600"
}
