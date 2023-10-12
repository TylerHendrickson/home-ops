resource "kubernetes_persistent_volume_claim" "home-directory" {
  metadata {
    name      = "coder-ws-${data.coder_workspace.this.owner}-${data.coder_workspace.this.name}-home"
    namespace = "dev"
  }

  wait_until_bound = false

  spec {
    storage_class_name = "longhorn-coder-workspace"
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
    name      = "coder-ws-${data.coder_workspace.this.owner}-${data.coder_workspace.this.name}-dind"
    namespace = "dev"
  }

  wait_until_bound = false

  spec {
    storage_class_name = "longhorn-coder-workspace"
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
    name      = "coder-ws-${data.coder_workspace.this.owner}-${data.coder_workspace.this.name}-postgres"
    namespace = "dev"
  }

  wait_until_bound = false

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "longhorn-coder-workspace"
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}
