###############################################################################
# Cilium
#
# kube-proxy is disabled in the Talos config, so Cilium is the only dataplane.
# Nodes reach the API server through KubePrism on localhost:7445.
###############################################################################

locals {
  cilium_version = "1.20.2"

  # BGP: each site peers with its own VyOS router. PodCIDRs, the LoadBalancer
  # pool and ClusterIPs are advertised, so every Service is reachable from the
  # LAN by its ClusterIP (see the Service advertisement below).
  bgp = {
    jd = {
      local_asn    = 64512
      peer_asn     = 64550
      peer_address = "10.0.53.1"
    }
    linds = {
      local_asn    = 64513
      peer_asn     = 64551
      peer_address = "10.3.1.1"
    }
  }

  lb_pool_cidr = "172.16.1.0/24"

  # Cilium 1.20 serves these under cilium.io/v2 and warns on every v2alpha1
  # apply. Verified against the live CRDs with `kubectl apply --dry-run=server`.
  cilium_cr_api_version = "cilium.io/v2"

  cilium_values = {
    ipam = {
      mode = "kubernetes"
    }
    # Restart the agents when their ConfigMap changes. Without this a values
    # change (enable-service-topology on 2026-09-05, for one) only lands on a
    # node the next time it happens to reboot.
    rollOutCiliumPods    = true
    kubeProxyReplacement = true
    # Translate Service addresses once, at connect(), in every pod - not only
    # in the host namespace. hostNamespaceOnly = true leaves pods on the
    # per-packet path instead: DNAT, conntrack and reverse NAT on each packet
    # of every pod -> Service connection.
    #
    # The price is in one failure case. A TCP connection is pinned to the
    # backend chosen at connect(), and Cilium only force-closes UDP sockets
    # when a backend disappears. A pod that exits closes its own connections,
    # so restarts, rollouts and drains look the same as before; a backend that
    # vanishes without a FIN (its node dies) leaves its TCP clients waiting on
    # their own timeouts, where the per-packet path would have reset them.
    #
    # The chart forces hostNamespaceOnly to true whenever gatewayAPI.enabled
    # is set, whatever is written here, so the two have to stay off together.
    # See the note where gatewayAPI used to be, below.
    socketLB = {
      enabled           = true
      hostNamespaceOnly = false
    }
    # Honour Service.spec.trafficDistribution (EndpointSlice zone hints) so a
    # linds pod resolving via kube-dns, or hitting any other Service with
    # endpoints at both sites, stays on its own site. Needs the
    # topology.kubernetes.io/zone node label set in talos.tf.
    #
    # mode and acceleration are the chart defaults, written out because this
    # file asked for "hybrid" and "best-effort" from the day Cilium went in and
    # never got them: they sat under a lower-case `loadbalancer` key, which
    # Helm ignores. The cluster has always run SNAT with no XDP. Both are the
    # right answer for this network, so now they are set on purpose.
    #
    # snat: under DSR (and hybrid is DSR for TCP) the backend's node answers
    # the client directly, from the Service address. Inside one site that is
    # fine. Across sites the forwarded request (client -> pod) and the reply
    # (Service -> client) both cross the two routers and the IPsec tunnel, but
    # as unrelated half-connections: the far router is asked to forward a
    # SYN-ACK for which it never saw a SYN. Whether that survives depends on
    # each router's firewall staying lenient. SNAT keeps both directions in
    # one flow on one path.
    #
    # disabled: the nodes' NICs are virtio-net, and attaching an XDP program
    # to virtio-net turns off the guest's receive offloads (rx-gro-hw) for as
    # long as it stays attached. Those offloads are why traffic from another
    # VM on the same host, and iSCSI and NFS from the host itself, arrive as
    # 64 KiB segments rather than 1500-byte frames. XDP would speed up one
    # thing - forwarding a LAN request on to a backend on another node - and
    # slow down everything else the NIC receives.
    loadBalancer = {
      serviceTopology = true
      mode            = "snat"
      acceleration    = "disabled"
    }
    pmtuDiscovery = {
      enabled = true
    }
    bandwidthManager = {
      enabled = true
      bbr     = true
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
    # No gatewayAPI block: it was enabled here and never worked. The Gateway
    # API CRDs are not installed, so the operator logged "Required GatewayAPI
    # resources are not found" at every start and ran no controller; nothing
    # in LINDS-Kubernetes uses Gateway API (ingress is the two nginx classes).
    #
    # It was not free, though. With gatewayAPI.enabled the 1.20 chart forces
    # bpf-lb-sock-hostns-only and enable-envoy-config on, and either one
    # compiles per-packet Service load-balancing into every pod's datapath
    # (ENABLE_PER_PACKET_LB in bpf_lxc.c). `cilium-dbg status` said so:
    # "Socket LB Coverage: Hostns-only".
    #
    # To use Gateway API later: install its CRDs first, then expect that
    # switch to come back with it. L7 and FQDN policies do not need it - the
    # L7 proxy stays enabled (chart default), and with no such policy in the
    # cluster no Envoy process is even running on the nodes.
    bgpControlPlane = {
      enabled = true
    }
    envoy = {
      enabled = false
    }
    # Native routing: PodCIDRs are BGP-advertised to both VyOS routers, so no
    # encapsulation is needed. Geneve-in-IPsec was dropped by the router (GRO
    # merges tunneled TCP into GSO packets the vti/xfrm path cannot segment),
    # and native pod TCP gets MSS-clamped by vti0 clamp-mss-to-pmtu.
    routingMode           = "native"
    ipv4NativeRoutingCIDR = "10.244.0.0/16"
    autoDirectNodeRoutes  = true
    # Nodes span two L2 segments (10.0.53.0/24 and 10.3.1.0/24); skip direct
    # routes for the remote site and fall back to the default gateway.
    directRoutingSkipUnreachable = true
    bpf = {
      masquerade = true
      # Per-CPU LRU for the conntrack and NAT maps: no shared lock, but a
      # map's capacity is split evenly across CPUs and a CPU that runs out
      # evicts its own entries even while the others sit empty. Upstream says
      # to raise the map size along with it. At the default ratio (0.0025) a
      # 16 GiB node gets 146,904 TCP conntrack entries, i.e. 18,363 per CPU on
      # the 8-vCPU nodes, and the busiest node holds about 10,000 in total.
      #
      # Doubling it gives 36,700 per CPU. These are LRU maps, so the memory is
      # allocated up front whether used or not: bpftool shows 70 MiB for the
      # five scaled maps at the default, so this costs another 70 MiB a node.
      # The 0.08 in Cilium's tuning guide would be 2.2 GiB a node, to hold
      # those same 10,000 entries.
      distributedLRU = {
        enabled = true
      }
      mapDynamicSizeRatio = 0.005
      enableTCX           = true
      lbExternalClusterIP = true
    }
    # BIG TCP needs a NIC that can send >64 KiB GSO packets (mlx5, ice).
    # virtio-net caps tso_max_size at 65536, so there is nothing to enable.
    enableIPv4BIGTCP     = false
    enableIPv4Masquerade = true
    endpointRoutes = {
      enabled = false
    }

    conntrackGCInterval = "0s"

    wellKnownIdentities = {
      enabled = true
    }

    bpfClockProbe = true

    prometheus = {
      enabled = true
      serviceMonitor = {
        enabled = true
      }
    }

    operator = {
      prometheus = {
        enabled = true
        serviceMonitor = {
          enabled = true
        }
      }
    }

    hubble = {
      enabled = true
      metrics = {
        enableOpenMetrics = true
        # httpV2 needs L7 proxy visibility to produce anything (there are no
        # L7 policies here, so it only paid the accounting cost) and
        # port-distribution is a high-cardinality series per node. Both
        # dropped; dns/drop/tcp/flow/icmp keep the Hubble UI fully functional.
        enabled = ["dns", "drop", "tcp", "flow", "icmp"]
        serviceMonitor = {
          enabled = true
        }
      }
      relay = {
        enabled = true
      }
      ui = {
        enabled = true
        ingress = {
          enabled   = true
          className = "nginx"
          annotations = {
            "cert-manager.io/cluster-issuer" = "linds-ca"
            # Kyverno adds these to every other Ingress (server-auth EKU so
            # iOS/macOS accept the leaf) but skips kube-system, so set them
            # here by hand. Values match kyverno/ingress-cert-server-auth.yaml.
            "cert-manager.io/usages"   = "digital signature, key encipherment, server auth"
            "cert-manager.io/duration" = "2160h"
          }
          hosts = ["hubble.linds.com.au"]
          tls = [
            {
              secretName = "hubble-linds-tls"
              hosts      = ["hubble.linds.com.au"]
            }
          ]
        }
      }
    }
  }

  ###########################################################################
  # Cilium BGP CRs
  #
  # These cannot be kubernetes_manifest resources: that provider reads the CRD
  # schema at plan time, which does not exist until the Cilium release above
  # has been installed. They are rendered here and applied with kubectl so the
  # ordering works on a from-scratch bootstrap.
  ###########################################################################
  cilium_bgp_manifests = concat(
    [
      {
        apiVersion = local.cilium_cr_api_version
        kind       = "CiliumBGPPeerConfig"
        metadata   = { name = "cilium-peer-config" }
        spec = {
          ebgpMultihop = 1
          timers = {
            holdTimeSeconds         = 90
            keepAliveTimeSeconds    = 30
            connectRetryTimeSeconds = 120
          }
          gracefulRestart = {
            enabled            = true
            restartTimeSeconds = 120
          }
          families = [
            {
              afi  = "ipv4"
              safi = "unicast"
              advertisements = {
                matchLabels = { advertise = "bgp" }
              }
            }
          ]
        }
      }
    ],
    [
      for site in sort(keys(local.bgp)) : {
        apiVersion = local.cilium_cr_api_version
        kind       = "CiliumBGPClusterConfig"
        metadata   = { name = "cilium-bgp-${site}" }
        spec = {
          nodeSelector = {
            matchLabels = { datacenter = site }
          }
          bgpInstances = [
            {
              name     = "${site}-instance"
              localASN = local.bgp[site].local_asn
              peers = [
                {
                  name        = "${site}-vyos-01-peer"
                  peerASN     = local.bgp[site].peer_asn
                  peerAddress = local.bgp[site].peer_address
                  peerConfigRef = {
                    name = "cilium-peer-config"
                  }
                }
              ]
            }
          ]
        }
      }
    ],
  )

  cilium_lb_manifests = [
    {
      apiVersion = local.cilium_cr_api_version
      kind       = "CiliumLoadBalancerIPPool"
      metadata = {
        name   = "lb-pool"
        labels = { pool = "lb" }
      }
      spec = {
        blocks = [{ cidr = local.lb_pool_cidr }]
      }
    },
    {
      apiVersion = local.cilium_cr_api_version
      kind       = "CiliumBGPAdvertisement"
      metadata = {
        name   = "bgp-advertisements-service"
        labels = { advertise = "bgp" }
      }
      spec = {
        advertisements = [
          {
            advertisementType = "Service"
            service = {
              # ClusterIP is advertised as a /32 per Service from every node in
              # the site's BGP instance, so each VyOS sees an ECMP set and a
              # dead node drops out of the path set instead of blackholing.
              # This only works because bpf.lbExternalClusterIP is true above -
              # without it a node silently drops off-cluster traffic addressed
              # to a ClusterIP, and the route would be a black hole.
              #
              # Headless Services have no ClusterIP and are skipped; their
              # names resolve to pod IPs, which the PodCIDR advertisement
              # already makes routable.
              addresses = ["LoadBalancerIP", "ExternalIP", "ClusterIP"]
            }
            # Match every service.
            selector = {
              matchExpressions = [
                {
                  key      = "somekey"
                  operator = "NotIn"
                  values   = ["never-match-this"]
                }
              ]
            }
          }
        ]
      }
    },
    {
      apiVersion = local.cilium_cr_api_version
      kind       = "CiliumBGPAdvertisement"
      metadata = {
        name   = "bgp-advertisements-podcidr"
        labels = { advertise = "bgp" }
      }
      spec = {
        advertisements = [{ advertisementType = "PodCIDR" }]
      }
    },
    # NOTE: there used to be a "bgp-advertisements-lbpool" advertisement here
    # using advertisementType = "CiliumLoadBalancerIPPool". That value is not
    # supported by the CRD - only PodCIDR, CiliumPodIPPool and Service are - so
    # it never applied cleanly and the CR has never existed on the cluster.
    # LoadBalancer addresses are advertised individually by the Service
    # advertisement above, which is the mechanism that actually works.
  ]

  cilium_bgp_yaml = join("\n---\n", [
    for m in concat(local.cilium_bgp_manifests, local.cilium_lb_manifests) : yamlencode(m)
  ])
}

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  namespace  = "kube-system"
  version    = local.cilium_version

  # The agents roll two at a time across seven nodes, and each one rebuilds
  # its datapath before it reports ready. The default of 300 s has been too
  # short twice (revisions 32 and 33, "context deadline exceeded"), which
  # leaves the release marked failed with the rollout still in progress.
  timeout = 900

  values = [yamlencode(local.cilium_values)]

  depends_on = [talos_cluster_kubeconfig.this]
}

resource "null_resource" "cilium_bgp_config" {
  # Hashes the rendered manifests, so editing any of the CRs above actually
  # re-applies them. The previous hand-maintained `config_version` counter did
  # not, and silently went stale.
  triggers = {
    manifests = sha256(local.cilium_bgp_yaml)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    # The manifests are passed through the environment rather than interpolated
    # into a heredoc. Embedding them coupled the YAML's indentation to the
    # script's: `indent()` skips the first line by design, Terraform's <<- then
    # stripped the literal spaces standing in for it, and the first line landed
    # at column 0 while the rest sat at 6 - unparseable.
    environment = {
      KUBECONFIG    = local_file.kubeconfig.filename
      BGP_MANIFESTS = local.cilium_bgp_yaml
    }

    command = <<-EOT
      set -euo pipefail

      echo "Waiting for Cilium BGP CRDs..."
      until kubectl get crd ciliumbgpclusterconfigs.cilium.io >/dev/null 2>&1; do
        sleep 5
      done

      printf '%s\n' "$BGP_MANIFESTS" | kubectl apply -f -
    EOT
  }

  depends_on = [
    helm_release.cilium,
    local_file.kubeconfig,
  ]
}
