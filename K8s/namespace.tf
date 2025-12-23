resource "kubernetes_namespace" "default" {
  metadata {
    name = "default"
  }
}

resource "kubernetes_namespace" "unifi" {
  metadata {
    name = "unifi"
    labels = {
        "name" = "home"
    }
  }
}

resource "kubernetes_namespace" "tigera-operator" {
  metadata {
    name = "tigera-operator"
    labels = {
        "name" = "tigera-operator"
    }
  }
}