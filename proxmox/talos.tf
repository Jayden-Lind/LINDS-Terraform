###############################################################################
# Talos cluster configuration
#
# Single control plane at 10.0.53.200, four workers at .201-.204 on the JD
# site, two workers at 10.3.1.100-101 on the LINDS site. Scheduling is allowed
# on the control plane.
###############################################################################

locals {
  talos_version      = "v1.13.8"
  kubernetes_version = "v1.36.3"

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
      }
      # Declarative replacement for the old node_labels local-exec hack.
      # LINDS workers override this to datacenter=linds below.
      nodeLabels = {
        datacenter = "jd"
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
        "net.core.somaxconn"              = "65535"
        "net.core.netdev_max_backlog"     = "65535"
        "net.core.rmem_max"               = "16777216"
        "net.core.wmem_max"               = "16777216"
        "net.core.default_qdisc"          = "noqueue"
        "net.core.busy_poll"              = "50"
        "net.core.busy_read"              = "50"
        "net.ipv4.tcp_rmem"               = "4096 87380 16777216"
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

  # LINDS nodes are Intel Broadwell - separate installer schematic and label.
  talos_common_config_linds = merge(local.talos_common_config, {
    machine = merge(local.talos_common_config.machine, {
      install = {
        disk  = "/dev/sda"
        image = "factory.talos.dev/installer/${talos_image_factory_schematic.this["intel"].id}:${local.talos_version}"
      }
      nodeLabels = {
        datacenter = "linds"
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
              apiVersion = "pod-security.admission.config.k8s.io/v1alpha1"
              defaults = {
                audit             = "privileged"
                "audit-version"   = "latest"
                enforce           = "privileged"
                "enforce-version" = "latest"
                warn              = "privileged"
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
}

data "talos_machine_configuration" "worker" {
  cluster_name       = local.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = local.kubernetes_version
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

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = local.controlplane_node

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

  config_patches = [yamlencode(local.talos_common_config)]

  depends_on = [module.talos_workers_jd]
}

resource "talos_machine_configuration_apply" "worker_linds" {
  count = length(local.worker_nodes_lind)

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = local.worker_nodes_lind[count.index]

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
