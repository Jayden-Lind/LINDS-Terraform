resource "talos_machine_secrets" "this" {
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
    [for i in range(3) : "10.0.53.${201 + i}"]
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
    yamlencode({
      machine = {
        install = {
          image = "factory.talos.dev/installer/88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b:v1.11.6"
          disk = "/dev/sda"
          extensions = [
            {
              image = "ghcr.io/siderolabs/nfsd:v1.11.6"
            },
            {
              image = "ghcr.io/siderolabs/nfs-utils:v0.1.1"
            },
          ]
        }
      }
      cluster = {
        network = {
          cni = {
            name = "none"
          }
        }
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
    })
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
    yamlencode({
      machine = {
        install = {
          disk  = "/dev/sda"
          image = "factory.talos.dev/installer/88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b:v1.11.6"
          extensions = [
            {
              image = "ghcr.io/siderolabs/nfsd:v1.11.6"
            },
            {
              image = "ghcr.io/siderolabs/nfs-utils:v0.1.1"
            },
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
  })]

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
    yamlencode({
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
    })
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
