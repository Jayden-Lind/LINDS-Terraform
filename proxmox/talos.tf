resource "talos_machine_secrets" "this" {
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      extraKernelArgs = [
        "mitigations=off",
        "talos.auditd.disabled=1",
        "-init_on_alloc",
        "-init_on_free",
        "-selinux",
        "init_on_alloc=0",
        "init_on_free=0",
        "security=none"
      ]
      systemExtensions = {
        officialExtensions = [
          "siderolabs/crun",
          "siderolabs/iscsi-tools",
          "siderolabs/nfs-utils",
          "siderolabs/nfsd",
          "siderolabs/qemu-guest-agent",
          "siderolabs/util-linux-tools"
        ]
      }
    }
  })
}

locals {
  talos_common_config = {
    machine = {
      install = {
        disk  = "/dev/sda"
        image = "factory.talos.dev/installer/${talos_image_factory_schematic.this.id}:v1.12.4"
      }
      kubelet = {
        image = "ghcr.io/siderolabs/kubelet:v1.35.1-fat"
      }
      features = {
        hostDNS = {
          enabled              = true
          forwardKubeDNSToHost = true
        }
      }
      network = {
        interfaces = [
          {
            interface = "lo"
            addresses = ["169.254.116.108/32"]
          }
        ]
      }
    }
    cluster = {
      network = {
        cni = {
          name = "none"
        }
      }
    }
  }

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

  cilium_values = {
    ipam = {
      mode = "kubernetes"
    }
    kubeProxyReplacement = true
    socketLB = {
      enabled = true
    }
    loadbalancer = {
      acceleration = "best-effort"
      mode         = "hybrid"
    }
    k8sServiceHost = "localhost"
    k8sServicePort = 7445
    securityContext = {
      capabilities = {
        ciliumAgent      = ["CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
        cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
      }
    }
    cgroup = {
      autoMount = {
        enabled = false
      }
      hostRoot = "/sys/fs/cgroup"
    }
    gatewayAPI = {
      enabled           = true
      enableAlpn        = true
      enableAppProtocol = true
    }
    bgpControlPlane = {
      enabled = true
    }
    routingMode    = "tunnel"
    tunnelProtocol = "vxlan"
    tunnelPort     = 8472
    mtu = 1300
    autoDirectNodeRoutes = false
    bpf = {
      masquerade = true
      distributedLRU = {
        enabled = true
      }
      enableTCX = true
    }
    enableIPv4Masquerade = true
  }
}

data "talos_machine_configuration" "controlplane" {
  cluster_name     = "talos-cluster"
  cluster_endpoint = "https://10.0.53.200:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_machine_configuration" "worker" {
  cluster_name     = "talos-cluster"
  cluster_endpoint = "https://10.0.53.200:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_client_configuration" "this" {
  cluster_name         = "talos-cluster"
  client_configuration = talos_machine_secrets.this.client_configuration

  endpoints = ["10.0.53.200"]

  nodes = concat(
    ["10.0.53.200"],
    [for i in range(3) : "10.0.53.${201 + i}"],
    [for i in range(2) : "10.3.1.${100 + i}"]
  )
}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = "10.0.53.200"
  depends_on = [
    proxmox_virtual_environment_vm.talos_cp
  ]
  config_patches = [
    yamlencode(local.talos_common_config),
    yamlencode(local.talos_cp_config)
  ]
}

resource "talos_machine_configuration_apply" "worker" {
  count                       = 3
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = "10.0.53.${201 + count.index}"
  depends_on = [
    proxmox_virtual_environment_vm.talos_worker
  ]
  config_patches = [
    yamlencode(local.talos_common_config)
  ]
}

resource "talos_machine_configuration_apply" "worker_linds" {
  count                       = 2
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = "10.3.1.${100 + count.index}"
  depends_on = [
    proxmox_virtual_environment_vm.talos_worker_linds
  ]
  config_patches = [
    yamlencode(local.talos_common_config)
  ]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = "10.0.53.200"
  depends_on = [
    talos_machine_configuration_apply.controlplane
  ]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = "10.0.53.200"
  depends_on = [
    talos_machine_bootstrap.this
  ]
}

resource "helm_release" "cilium" {
  name             = "cilium"
  repository       = "https://helm.cilium.io/"
  chart            = "cilium"
  namespace        = "kube-system"
  version          = "1.19.0"

  values = [
    yamlencode(local.cilium_values)
  ]

  depends_on = [
    talos_cluster_kubeconfig.this
  ]
}

# Apply Cilium BGP configuration via kubectl to avoid CRD race condition
resource "null_resource" "cilium_bgp_config" {
  depends_on = [
    helm_release.cilium,
    null_resource.node_labels
  ]

  triggers = {
    bgp_config_hash = sha256(jsonencode({
      jd_asn             = 64512
      linds_asn          = 64513
      jd_peer            = "10.0.53.1"
      linds_peer         = "10.3.1.1"
      lb_cidr            = "172.16.1.0/24"
      lb_pool_advertise  = true
      config_version     = 2
    }))
  }

  provisioner "local-exec" {
    command     = <<EOT
      export KUBECONFIG=${path.module}/kubeconfig

      # Wait for Cilium CRDs to be available
      echo "Waiting for Cilium CRDs..."
      until kubectl get crd ciliumbgpclusterconfigs.cilium.io &>/dev/null; do
        sleep 5
      done
      echo "Cilium CRDs are ready"

      # Apply BGP Peer Config
      kubectl apply -f - <<EOF
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPPeerConfig
metadata:
  name: cilium-peer-config
spec:
  ebgpMultihop: 1
  timers:
    holdTimeSeconds: 90
    keepAliveTimeSeconds: 30
    connectRetryTimeSeconds: 120
  gracefulRestart:
    enabled: true
    restartTimeSeconds: 120
  families:
    - afi: ipv4
      safi: unicast
      advertisements:
        matchLabels:
          advertise: bgp
EOF

      # Apply JD BGP Cluster Config
      kubectl apply -f - <<EOF
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPClusterConfig
metadata:
  name: cilium-bgp-jd
spec:
  nodeSelector:
    matchLabels:
      datacenter: jd
  bgpInstances:
    - name: jd-instance
      localASN: 64512
      peers:
        - name: jd-vyos-01-peer
          peerASN: 64550
          peerAddress: 10.0.53.1
          peerConfigRef:
            name: cilium-peer-config
EOF

      # Apply LINDS BGP Cluster Config
      kubectl apply -f - <<EOF
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPClusterConfig
metadata:
  name: cilium-bgp-linds
spec:
  nodeSelector:
    matchLabels:
      datacenter: linds
  bgpInstances:
    - name: linds-instance
      localASN: 64513
      peers:
        - name: linds-vyos-01-peer
          peerASN: 64551
          peerAddress: 10.3.1.1
          peerConfigRef:
            name: cilium-peer-config
EOF

      # Apply LoadBalancer IP Pool
      kubectl apply -f - <<EOF
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: lb-pool
  labels:
    pool: lb
spec:
  blocks:
    - cidr: 172.16.1.0/24
EOF

      # Apply BGP Advertisement for Services (LoadBalancer and ExternalIP only)
      # NOTE: ClusterIP is NOT advertised - it must be handled internally by Cilium
      kubectl apply -f - <<EOF
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPAdvertisement
metadata:
  name: bgp-advertisements-service
  labels:
    advertise: bgp
spec:
  advertisements:
    - advertisementType: Service
      service:
        addresses:
          - LoadBalancerIP
          - ExternalIP
      selector:
        matchExpressions:
          - key: somekey
            operator: NotIn
            values: ['never-match-this']
EOF

      # Apply BGP Advertisement for PodCIDR
      kubectl apply -f - <<EOF
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPAdvertisement
metadata:
  name: bgp-advertisements-podcidr
  labels:
    advertise: bgp
spec:
  advertisements:
    - advertisementType: PodCIDR
EOF

      # Apply BGP Advertisement for LoadBalancer IP Pool CIDR
      kubectl apply -f - <<EOF
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPAdvertisement
metadata:
  name: bgp-advertisements-lbpool
  labels:
    advertise: bgp
spec:
  advertisements:
    - advertisementType: CiliumLoadBalancerIPPool
      selector:
        matchLabels:
          pool: lb
EOF

      echo "Cilium BGP configuration applied successfully"
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}


resource "local_file" "talosconfig" {
  filename        = "${path.module}/talosconfig"
  content         = data.talos_client_configuration.this.talos_config
  file_permission = "0600"

  depends_on = [
    data.talos_client_configuration.this
  ]
}

resource "local_file" "kubeconfig" {
  filename        = "${path.module}/kubeconfig"
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  file_permission = "0600"

  depends_on = [
    talos_cluster_kubeconfig.this
  ]
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

resource "null_resource" "node_labels" {
  depends_on = [
    talos_cluster_kubeconfig.this,
    talos_machine_configuration_apply.controlplane,
    talos_machine_configuration_apply.worker,
    talos_machine_configuration_apply.worker_linds
  ]

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command     = <<EOT
      export KUBECONFIG=${path.module}/kubeconfig

      # Label JD Control Plane and Workers
      NODES_JD=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name" | grep -E "^talos-cp|^talos-worker" || true)
      for node in $NODES_JD; do
        [ -z "$node" ] && continue
        kubectl label nodes $node datacenter=jd --overwrite
      done

      # Label Linds Workers
      NODES_LINDS=$(kubectl get nodes --no-headers -o custom-columns=":metadata.name" | grep "^talos-linds-worker" || true)
      for node in $NODES_LINDS; do
        [ -z "$node" ] && continue
        kubectl label nodes $node datacenter=linds --overwrite
      done
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}
