locals {
  kubernetes_storage_class_name = "longhorn-coder-workspace-v2"
}

resource "kubernetes_persistent_volume_claim" "home-directory" {
  metadata {
    name      = "${local.kubernetes_resource_prefix}-home"
    namespace = local.kubernetes_namespace
  }

  wait_until_bound = false

  spec {
    storage_class_name = local.kubernetes_storage_class_name
    access_modes       = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "20Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "dind" {
  metadata {
    name      = "${local.kubernetes_resource_prefix}-dind"
    namespace = local.kubernetes_namespace
  }

  wait_until_bound = false

  spec {
    storage_class_name = local.kubernetes_storage_class_name
    access_modes       = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "postgres-data-directory" {
  metadata {
    name      = "${local.kubernetes_resource_prefix}-postgres"
    namespace = local.kubernetes_namespace
  }

  wait_until_bound = false

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = local.kubernetes_storage_class_name
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}
