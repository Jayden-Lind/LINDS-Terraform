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
        image = "factory.talos.dev/installer/${talos_image_factory_schematic.this.id}:v1.12.0"
      }
      kubelet = {
        image = "ghcr.io/siderolabs/kubelet:v1.35.0-fat"
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
                namespaces     = ["calico-system"]
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

  calico_values = {
    installation = {
      calicoNetwork = {
        containerIPForwarding = "Enabled"
        bgp                   = "Enabled"
        mtu                   = 1300
        kubeProxyManagement   = "Enabled"
        bpfNetworkBootstrap   = "Disabled"
        linuxDataplane        = "BPF"
        ipPools = [
          {
            name             = "default-ipv4-ippool"
            cidr             = "10.244.0.0/16"
            blockSize        = 26
            encapsulation    = "IPIPCrossSubnet"
            natOutgoing      = "Enabled"
            disableBGPExport = false
            nodeSelector     = "all()"
          },
          {
            name           = "lb-172-16-1"
            cidr           = "172.16.1.0/24"
            blockSize      = 24
            encapsulation  = "None"
            natOutgoing    = "Disabled"
            assignmentMode = "Automatic"
            allowedUses    = ["LoadBalancer"]
            nodeSelector   = "all()"
          }
        ]
      }
    }
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

resource "helm_release" "calico" {
  name             = "calico"
  repository       = "https://docs.projectcalico.org/charts"
  chart            = "tigera-operator"
  namespace        = "tigera-operator"
  create_namespace = true
  version          = "v3.31.3"

  values = [
    yamlencode(local.calico_values)
  ]

  depends_on = [
    talos_cluster_kubeconfig.this
  ]
}

resource "kubernetes_config_map" "calico_kubernetes_services_endpoint" {
  metadata {
    name      = "kubernetes-services-endpoint"
    namespace = "tigera-operator"
  }

  data = {
    KUBERNETES_SERVICE_HOST = "10.0.53.200"
    KUBERNETES_SERVICE_PORT = "6443"
  }

  depends_on = [
    helm_release.calico
  ]
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
