###############################################################################
# Talos cluster configuration
#
# Single control plane at 10.0.53.200, four workers at .201-.204 on the JD
# site, two workers at 10.3.1.100-101 on the LINDS site. Scheduling is allowed
# on the control plane, but a soft taint keeps ordinary pods off it when a
# worker has room (talos_cp_docs).
#
# Each node has a static address, hostname and resolver (talos_node_docs).
# The Kea reservations on the site routers stay: a node in maintenance mode
# (booted from the ISO, no config yet) still gets its address from them.
###############################################################################

locals {
  # Upgrade order, which deploy/linds-tf-deploy follows on every merge to main:
  # bump talos_version, `terraform apply` (machine config only -
  # nothing reboots), then `talosctl upgrade` node by node with the installer
  # image from `terraform output talos_installer_images`. Only after every node
  # runs the new Talos bump kubernetes_version and apply again - control plane
  # first (-target the controlplane apply), then the workers.
  #
  # That wait is for a Kubernetes *minor* the running Talos does not support
  # yet. A patch release of the current minor (v1.37.0 -> v1.37.1 here) can go
  # in the same apply as the Talos bump; the control plane still goes first.
  talos_version      = "v1.14.6"
  kubernetes_version = "v1.37.2"

  # Version contract the machine config is *generated* against - which schema
  # and defaults the provider emits. It is not the installed Talos version and
  # does not follow talos_version above.
  #
  # Left unset it tracks the Talos SDK bundled in the provider, so a provider
  # upgrade could silently regenerate every node's config.
  #
  # From the v1.14 contract the base config is one document for each feature
  # (KubeletConfig, KubeNodeConfig, ResolverConfig, LinkConfig, ...). Only the
  # secrets and a few fields stay in the old `machine:` / `cluster:` document.
  # Talos rejects a config that sets the same thing in both places, so the
  # patches below are all documents of the new type (talos_*_docs).
  #
  # The v1.14 base config also turns on some things that this cluster did not
  # have with the v1.13 contract. talos_common_docs turns each of them off
  # again, so that the move to v1.14 changed the format and not the nodes.
  # Read the comments there before you remove one.
  #
  # Before you raise the contract again: render the config with the new
  # value, compare it with the old render, and apply it to one worker with
  # `talosctl apply-config --mode=try`.
  talos_config_contract = "v1.14"

  cluster_name     = "talos-cluster"
  cluster_endpoint = "https://10.0.53.200:6443"

  controlplane_node = "10.0.53.200"
  worker_nodes_jd   = [for i in range(4) : "10.0.53.${201 + i}"]
  worker_nodes_lind = [for i in range(2) : "10.3.1.${100 + i}"]

  # Per-site network values. They are the values that DHCP gave the nodes
  # until 2026-11-10, so the change to static addresses changed no address,
  # route or resolver.
  #
  # schematic: the key of the image factory schematic for the installer
  # image. The LINDS nodes are Intel Broadwell; the two schematics give the
  # same image at this time (see talos-schematic.tf).
  #
  # ntp: the site router is first. It runs chrony, follows the internet
  # sources itself, and continues to serve time when the WAN is down, so the
  # nodes of a site stay in step with each other. The internet servers stay
  # as the fallback for when the router does not answer.
  talos_sites = {
    jd = {
      subnet      = "10.0.53.0/24"
      gateway     = "10.0.53.1"
      nameservers = ["10.0.53.1"]
      ntp         = ["10.0.53.1", "time.cloudflare.com", "pool.ntp.org"]
      schematic   = "amd"
    }
    linds = {
      subnet      = "10.3.1.0/24"
      gateway     = "10.3.1.1"
      nameservers = ["10.3.1.1", "10.3.1.200"]
      ntp         = ["10.3.1.1", "time.cloudflare.com", "pool.ntp.org"]
      schematic   = "intel"
    }
  }

  # Node address => hostname and site. The hostname is the Kubernetes node
  # name. NEVER change a hostname here: the kubelet would register a second
  # Node object and the pods, volumes and labels of the old one would not
  # follow.
  talos_nodes = merge(
    { (local.controlplane_node) = { hostname = "talos-cp", site = "jd" } },
    { for i, ip in local.worker_nodes_jd : ip => { hostname = format("talos-worker-%02d", i + 1), site = "jd" } },
    { for i, ip in local.worker_nodes_lind : ip => { hostname = format("talos-linds-worker-%02d", i + 1), site = "linds" } },
  )

  # The per-node documents: everything that differs between nodes or sites.
  #
  # Why static. With DHCP, the address of the API endpoint (10.0.53.200)
  # depended on Kea on jd-router-01, which is a VM on the same host as the
  # control plane. After a cold start with the router down, or a router
  # outage longer than the lease, the nodes had no address and could not
  # reach each other on their own VLAN.
  #
  # LinkConfig: `ens18` is the single virtio NIC that the talos-node module
  # gives each VM. Talos starts DHCP only on a NIC that has no LinkConfig, so
  # this document also stops DHCP. A route with no destination is the
  # default route. The metric 1024 is the one the DHCP route had.
  #
  # KubeNodeConfig: nodeIP.validSubnets makes the kubelet take its node IP
  # from the node subnet only, never from an address that Cilium or a later
  # interface adds. The labels replaced the old node_labels local-exec hack.
  # topology.kubernetes.io/zone is what Kubernetes topology-aware routing
  # (Service.spec.trafficDistribution) and Cilium's serviceTopology key on;
  # `datacenter` stays as the label the existing nodeSelectors and spread
  # constraints in LINDS-Kubernetes use. Same value, two consumers.
  #
  # HostnameConfig: the base config has `auto: stable` (a name made from the
  # machine ID). `auto: off` is necessary: a patch that only adds `hostname`
  # leaves both set, and Talos rejects that.
  #
  # UnattendedInstallConfig: the installer image, which `talosctl upgrade`
  # and a first install use. The disk (/dev/sda) is repeated from the base
  # config so that it does not depend on a default. Talos does not install
  # again on a node that is installed.
  talos_node_docs = {
    for ip, node in local.talos_nodes : ip => [
      {
        apiVersion = "v1alpha1"
        kind       = "LinkConfig"
        name       = "ens18"
        addresses = [
          { address = "${ip}/${split("/", local.talos_sites[node.site].subnet)[1]}" },
        ]
        routes = [
          {
            gateway = local.talos_sites[node.site].gateway
            metric  = 1024
          },
        ]
      },
      {
        apiVersion  = "v1alpha1"
        kind        = "ResolverConfig"
        nameservers = [for address in local.talos_sites[node.site].nameservers : { address = address }]
        searchDomains = {
          domains = ["linds.com.au"]
        }
      },
      {
        apiVersion = "v1alpha1"
        kind       = "TimeSyncConfig"
        ntp = {
          servers = local.talos_sites[node.site].ntp
        }
      },
      {
        apiVersion = "v1alpha1"
        kind       = "KubeNodeConfig"
        nodeIP = {
          validSubnets = [local.talos_sites[node.site].subnet]
        }
        labels = {
          datacenter                    = node.site
          "topology.kubernetes.io/zone" = node.site
        }
      },
      {
        apiVersion = "v1alpha1"
        kind       = "HostnameConfig"
        auto       = "off"
        hostname   = "${node.hostname}.linds.com.au"
      },
      {
        apiVersion = "v1alpha1"
        kind       = "UnattendedInstallConfig"
        installer = {
          image = "factory.talos.dev/installer/${talos_image_factory_schematic.this[local.talos_sites[node.site].schematic].id}:${local.talos_version}"
        }
        provisioning = {
          diskSelector = {
            match = "disk.dev_path == \"/dev/sda\""
          }
          wipe = false
        }
      },
    ]
  }

  # The documents that every node gets.
  talos_common_docs = [
    {
      apiVersion = "v1alpha1"
      kind       = "KubeletConfig"
      image      = "ghcr.io/siderolabs/kubelet:${local.kubernetes_version}-fat"
      # `config` is the KubeletConfiguration (the old machine.kubelet.extraConfig).
      config = {
        # Pull images in parallel instead of one at a time per node; a
        # drained node coming back was serialising 15+ pulls.
        serializeImagePulls   = false
        maxParallelImagePulls = 5

        # Talos reserves 512Mi of memory for everything that is not a pod.
        # Measured on 2026-11-10 (talosctl cgroups --preset=memory), the
        # init, system and podruntime groups (kubelet, containerd, the
        # Talos services) together held 1.2 GiB on a worker and 2.9 GiB on
        # the control plane, with peaks of 2.5 to 2.8 GiB. The scheduler
        # therefore thought each 16 GiB node had about 1 GiB more for pods
        # than it has. Part of that memory is page cache which the kernel
        # can take back, so 1536Mi is the reservation, not the peak.
        #
        # The other three values are the Talos defaults. A map in `config`
        # replaces the default map, so they are repeated.
        systemReserved = {
          cpu                 = "50m"
          memory              = "1536Mi"
          "ephemeral-storage" = "256Mi"
          pid                 = "100"
        }
        # The kubelet default starts to evict pods when 100Mi is free. On a
        # 16 GiB node that is too late: the kernel OOM killer comes first
        # and does not choose by pod priority. The four disk values are
        # the kubelet defaults, repeated for the same reason as above.
        evictionHard = {
          "memory.available"   = "500Mi"
          "nodefs.available"   = "10%"
          "nodefs.inodesFree"  = "5%"
          "imagefs.available"  = "15%"
          "imagefs.inodesFree" = "5%"
        }
        # No pod could start more than this number of processes and
        # threads. Without a limit (-1) one pod can use every PID of the
        # node. On 2026-11-10 all the pods of the busiest node together
        # had a peak of 1034.
        podPidsLimit = 4096
      }
    },
    {
      apiVersion = "v1alpha1"
      kind       = "ResolverConfig"
      hostDNS = {
        enabled = true
        # CoreDNS forwards straight to the upstream DNS servers now
        # (base/coredns.yml in LINDS-Kubernetes): the 169.254.116.108
        # hostDNS hop dropped queries under Cilium socketLB. The v1.14 base
        # config has `true` here.
        forwardKubeDNSToHost = false
      }
    },
    {
      apiVersion = "v1alpha1"
      kind       = "KubePrismConfig"
      port       = 7445
    },
    {
      apiVersion = "v1alpha1"
      kind       = "SysctlConfig"
      params = {
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
    },
    # No KubeSpan and a single cluster: the public discovery service is
    # unused and was just logging "discovery.talos.dev unreachable" noise.
    # The v1.14 base config has this document, and discovery is off only
    # when the document is absent, so the patch deletes it.
    {
      apiVersion = "v1alpha1"
      kind       = "DiscoveryServiceConfig"
      name       = "default"
      "$patch"   = "delete"
    },
    # The next two documents keep the nodes as they were with the v1.13
    # contract. The v1.14 base config has `true` for both, which is correct
    # for a new cluster. Each is a change to make on purpose and to test on
    # one worker first, not as a side effect of the config format:
    #
    # - mount.secure adds nosuid and nodev to /var (EPHEMERAL), where the
    #   pod volumes and the container images are.
    # - workloadIsolation moves containerd and the kubelet into a different
    #   set of namespaces from the Talos services.
    {
      apiVersion = "v1alpha1"
      kind       = "VolumeConfig"
      name       = "EPHEMERAL"
      mount = {
        secure = false
      }
    },
    {
      apiVersion        = "v1alpha1"
      kind              = "SecurityProfileConfig"
      workloadIsolation = false
    },
    # Periodic fstrim of the Talos-managed filesystems, a v1.14 feature that is
    # on for clusters created on v1.14 and off for upgraded ones until this
    # document exists.
    #
    # /var (EPHEMERAL) is mounted without `discard`, and every node's disk is
    # thin-provisioned: a zvol on ssd-mixed at JD, LVM-thin at LINDS. Nothing
    # was handing freed blocks back, so each disk only ever grew towards its
    # 75 G. On 2026-10-03 the two LINDS workers had ~70 G allocated in the thin
    # pool for 14 G and 24 G in use.
    #
    # The VMs already pass discards through (discard=on, ssd=1 in the talos-node
    # module). A week is what Talos generates for new clusters; each node and
    # volume gets its own slot inside the interval, so they do not all trim at
    # once.
    {
      apiVersion = "v1alpha1"
      kind       = "FilesystemTrimConfig"
      interval   = "168h0m0s"
    },
    # The NFS client reads ahead 128 KiB by default. A program that reads a
    # file in small parts then sends one 128 KiB request after the other.
    # With 16 MiB the client sends 1 MiB requests, and a sequential read
    # from jd-proxmox-02 is about four times as fast (measured in the Plex
    # pod: 610 MB/s to 2.4 GB/s). A random read does not start read-ahead.
    #
    # NFS mounts are the only devices with the name 0:* in the class bdi on
    # these nodes. An SMB mount has the name cifs-*.
    #
    # Udev rules have no document of the new type in Talos v1.14, so this
    # patch stays in the old `machine:` document. Talos applies it without
    # a reboot, also to the mounts that exist.
    {
      machine = {
        udev = {
          rules = [
            "SUBSYSTEM==\"bdi\", KERNEL==\"0:*\", ACTION==\"add|change\", ATTR{read_ahead_kb}=\"16384\"",
          ]
        }
      }
    },
  ]

  # The documents that only the control plane gets.
  talos_cp_docs = [
    # A soft taint. The scheduler puts a pod on the control plane only when
    # no worker can take it. Pods that are there already stay until they
    # restart, and DaemonSet pods are not affected.
    #
    # Why: this node is also etcd and the API server, on a disk with slow
    # fsync. Prometheus, Keycloak and others had landed on it (61% of its
    # memory on 2026-11-10), and workloads on this node have stalled etcd
    # before. A hard NoSchedule taint (the default of the base config) is
    # not used: when the JD workers are full or drained, the control plane
    # must still be able to take pods.
    #
    # The base config has the labels and the NoSchedule taint of a control
    # plane in this document. A patch adds to the map of labels, and
    # replaces the value of the taint. The empty value before the colon is
    # the value of the taint; PreferNoSchedule is its effect.
    {
      apiVersion = "v1alpha1"
      kind       = "KubeNodeConfig"
      taints = {
        "node-role.kubernetes.io/control-plane" = ":PreferNoSchedule"
      }
    },
    # There is one control plane node, so there is never a second
    # controller-manager or scheduler to elect against, yet each renewed its
    # lease every 2s. Lease renewals were 90% of all API writes here (6.4 of
    # 7.1 a second on 2026-10-04), and etcd turns each one into a WAL fsync
    # plus a bbolt commit: together they were most of the 58 GiB/day the
    # control plane VM writes to the SSD pool.
    #
    # Set both back to "true" BEFORE adding a second control plane node.
    # Two unelected controller-managers act on the cluster at the same time.
    {
      apiVersion = "v1alpha1"
      kind       = "KubeControllerManagerConfig"
      extraArgs = {
        "leader-elect" = "false"
      }
    },
    {
      apiVersion = "v1alpha1"
      kind       = "KubeSchedulerConfig"
      extraArgs = {
        "leader-elect" = "false"
      }
    },
    # etcd makes a write durable by fsyncing its WAL before it answers. The
    # bbolt database file is a second copy that it commits afterwards, every
    # 100ms by default whenever anything changed. With a write arriving every
    # 200ms or so that was four or five commits a second, each rewriting the
    # same few pages and fsyncing twice.
    #
    # 1s folds those into one commit. Nothing is less durable: after a crash
    # etcd replays from the WAL whatever the backend had not committed yet,
    # which is now up to a second of entries instead of a tenth of one.
    # Reads are unaffected - they see uncommitted writes through etcd's own
    # read buffer.
    #
    # etcd has no document of the new type in Talos v1.14. It is the only
    # patch that stays in the old `cluster:` document.
    {
      cluster = {
        etcd = {
          extraArgs = {
            "backend-batch-interval" = "1s"
          }
        }
      }
    },
    # Cilium is the CNI and replaces kube-proxy. They are installed from
    # LINDS-Terraform (cilium.tf), not by Talos. Flannel is off only when
    # its document is absent.
    {
      apiVersion = "v1alpha1"
      kind       = "KubeFlannelCNIConfig"
      "$patch"   = "delete"
    },
    {
      apiVersion = "v1alpha1"
      kind       = "KubeProxyConfig"
      enabled    = false
    },
    # Talos's default policy is one rule, `level: Metadata`, which records
    # every request twice (received and completed). That was a 100 MB file
    # every 42 minutes on this disk, 3.4 GiB/day - 17 times what every pod
    # in the cluster logs put together - and almost all of it was lease
    # renewals and controllers reading their own objects.
    #
    # What is kept is every change to the cluster: who created, updated,
    # patched or deleted what, and when. The first matching rule wins.
    # To audit reads of something again (Secrets, say), put a Metadata
    # rule for it above the get/list/watch rule.
    {
      apiVersion = "v1alpha1"
      kind       = "KubeAuditPolicyConfig"
      configuration = {
        apiVersion = "audit.k8s.io/v1"
        kind       = "Policy"
        omitStages = ["RequestReceived"]
        rules = [
          {
            level = "None"
            resources = [
              { group = "coordination.k8s.io", resources = ["leases"] },
            ]
          },
          {
            level = "None"
            verbs = ["get", "list", "watch"]
          },
          # Events are already a log. Token and access reviews are a
          # component asking the API server a question, not changing anything.
          {
            level = "None"
            resources = [
              { group = "", resources = ["events"] },
              { group = "events.k8s.io", resources = ["events"] },
              { group = "authentication.k8s.io", resources = ["tokenreviews"] },
              {
                group = "authorization.k8s.io"
                resources = [
                  "subjectaccessreviews",
                  "selfsubjectaccessreviews",
                  "selfsubjectrulesreviews",
                  "localsubjectaccessreviews",
                ]
              },
            ]
          },
          {
            level = "Metadata"
          },
        ]
      }
    },
    {
      apiVersion = "v1alpha1"
      kind       = "KubeAdmissionControlConfig"
      name       = "PodSecurity"
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
        # These empty lists do not empty the lists of the base config:
        # a patch cannot remove list entries. The base config exempts
        # kube-system, and that exemption is still live.
        exemptions = {
          namespaces     = []
          runtimeClasses = []
          usernames      = []
        }
        kind = "PodSecurityConfiguration"
      }
    },
    # The next two documents keep the API server as it was with the v1.13
    # contract: no anonymous requests at all, and no startup probe.
    #
    # The v1.14 base config lets anonymous requests read /livez, /readyz and
    # /healthz, because the startup probe of the new KubeAPIServerConfig
    # document reads /livez without a credential. The two go together: do
    # not set startupProbes to true while anonymous access is off, or the
    # kubelet restarts the API server when the probe fails.
    #
    # With the new document, the API server gets this as a file
    # (--authentication-config) and no longer as --anonymous-auth=false.
    {
      apiVersion = "v1alpha1"
      kind       = "KubeAuthenticationConfig"
      configuration = {
        anonymous = {
          enabled = false
        }
      }
    },
    {
      apiVersion    = "v1alpha1"
      kind          = "KubeAPIServerConfig"
      startupProbes = false
    },
  ]

  # The patch lists. Each document is one patch.
  talos_cp_patches = [
    for doc in concat(local.talos_common_docs, local.talos_node_docs[local.controlplane_node], local.talos_cp_docs) : yamlencode(doc)
  ]
  talos_worker_patches = {
    for ip in concat(local.worker_nodes_jd, local.worker_nodes_lind) : ip => [
      for doc in concat(local.talos_common_docs, local.talos_node_docs[ip]) : yamlencode(doc)
    ]
  }
}

resource "talos_machine_secrets" "this" {
}

# kubernetes_version pins the control plane static pod images (apiserver,
# controller-manager, scheduler). Without it the provider falls back to whatever
# it was built against, which is how the static pods ended up on v1.36.0 while
# the kubelets ran the v1.36.1 set by the kubelet image above.
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

  config_patches = local.talos_cp_patches

  depends_on = [module.talos_cp_jd]
}

resource "talos_machine_configuration_apply" "worker" {
  count = length(local.worker_nodes_jd)

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = local.worker_nodes_jd[count.index]
  apply_mode                  = "no_reboot"

  config_patches = local.talos_worker_patches[local.worker_nodes_jd[count.index]]

  depends_on = [module.talos_workers_jd]
}

resource "talos_machine_configuration_apply" "worker_linds" {
  count = length(local.worker_nodes_lind)

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = local.worker_nodes_lind[count.index]
  apply_mode                  = "no_reboot"

  config_patches = local.talos_worker_patches[local.worker_nodes_lind[count.index]]

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
