terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.11.2"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

data "coder_workspace" "this" {}

locals {
  postgres_user           = "postgres"
  postgres_password       = "password123"
  postgres_dev_dbname     = "usdr_grants"
  postgres_test_dbname    = "usdr_grants_test"
  node_version            = "16.14.0"
  port_forward_url_scheme = "${data.coder_workspace.this.access_port == 443 ? "https" : "http"}://"
  port_forward_domains = {
    for port in ["8080", "3000"] :
    port => join("-", [
      join("--", [port, "coder", data.coder_workspace.this.name, data.coder_workspace.this.owner]),
      "ws",
      trimprefix(data.coder_workspace.this.access_url, local.port_forward_url_scheme),
    ])
  }
  port_forward_urls = {
    for port, domain in local.port_forward_domains :
    port => "${local.port_forward_url_scheme}${domain}"
  }
  omz_plugins     = jsondecode(data.coder_parameter.oh_my_zsh_plugins.value)
  omz_plugins_cmd = length(local.omz_plugins) > 0 ? "source .zshrc && omz plugin enable ${join(" ", local.omz_plugins)}" : "true"
}

resource "coder_agent" "coder" {
  os   = "linux"
  arch = "amd64"
  dir  = "/home/coder/usdr-gost"

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "2_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "GOST Website Available?"
    key          = "3_gost_website_available"
    script       = "curl -sL --connect-timeout 5 localhost:8080 -o /dev/null && echo yes || echo no"
    interval     = 30
    timeout      = 10
  }

  metadata {
    display_name = "GOST API Available?"
    key          = "4_gost_api_available"
    script       = "curl -sL --connect-timeout 5 localhost:3000 -o /dev/null && echo yes || echo no"
    interval     = 30
    timeout      = 10
  }

  env = {
    PGHOST = "localhost"
    PGUSER = local.postgres_user
  }

  startup_script_timeout = 300
  startup_script = templatefile("${path.module}/tpl/coder_agent_startup_script.bash", {
    preferred_shell        = data.coder_parameter.preferred_shell.value
    oh_my_zsh_plugins_cmd  = local.omz_plugins_cmd
    dotfiles_uri           = "todo"
    postgres_user          = local.postgres_user
    postgres_password      = local.postgres_password
    postgres_dbs_to_create = [local.postgres_dev_dbname, local.postgres_test_dbname]
    postgres_envvar_dbname_map = {
      POSTGRES_URL      = local.postgres_dev_dbname
      POSTGRES_TEST_URL = local.postgres_test_dbname
    }
    nvm_install_script_url = "https://raw.githubusercontent.com/nvm-sh/nvm/${data.coder_parameter.nvm_version.value}/install.sh"
    yarn_network_timeout   = data.coder_parameter.yarn_network_timeout_ms.value
    git_clone_url          = "git@github.com:usdigitalresponse/usdr-gost.git"
    git_repo_name          = "usdr-gost"
    git_checkout_branch    = data.coder_parameter.git_checkout_branch_name.value
    git_base_branch        = data.coder_parameter.git_base_branch_name.value
    gost_api_url           = local.port_forward_urls["3000"]
    website_url            = local.port_forward_urls["8080"]
    vscode_extensions      = jsondecode(data.coder_parameter.vscode_extensions.value)
  })
}

# code-server
resource "coder_app" "code-server" {
  agent_id     = coder_agent.coder.id
  slug         = "code-server"
  display_name = "VS Code Web"
  icon         = "/icon/code.svg"
  url          = "http://localhost:13337?folder=/home/coder/usdr-gost"
  subdomain    = false
  share        = data.coder_parameter.sharing_mode.value

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }
}

locals {
  cpu-request    = "250m"
  memory-request = "500m"
  cpu-limit      = 3
  memory-limit   = "10G"

  main_docker_image = "ghcr.io/tortitude/coder-templates:gost-feature-development-v3"
}

resource "kubernetes_pod" "main" {
  count      = data.coder_workspace.this.start_count
  depends_on = [kubernetes_persistent_volume_claim.home-directory]

  metadata {
    name      = "coder-ws-${data.coder_workspace.this.owner}-${data.coder_workspace.this.name}"
    namespace = "dev"
  }

  spec {
    security_context {
      run_as_user = "1000"
      fs_group    = "1000"
    }

    container {
      name              = "workspace-container"
      image             = local.main_docker_image
      image_pull_policy = "Always"
      command           = ["sh", "-c", coder_agent.coder.init_script]

      security_context {
        run_as_user = "1000"
      }

      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.coder.token
      }
      env {
        name  = "PGUSER"
        value = local.postgres_user
      }
      env {
        name  = "PGHOST"
        value = "localhost"
      }
      env {
        name  = "EDGE_PORT"
        value = "4566"
      }
      env {
        name  = "LOCALSTACK_HOSTNAME"
        value = "localhost"
      }
      env {
        name  = "AWS_REGION"
        value = "us-west-2"
      }
      env {
        name  = "AWS_DEFAULT_REGION"
        value = "us-west-2"
      }
      env {
        name  = "DOCKER_HOST"
        value = "tcp://localhost:2375"
      }

      resources {
        requests = {
          cpu    = local.cpu-request
          memory = local.memory-request
        }
        limits = {
          cpu    = local.cpu-limit
          memory = local.memory-limit
        }
      }

      volume_mount {
        mount_path = "/home/coder"
        name       = "home-directory"
      }
    }

    container {
      name  = "docker-dind"
      image = "docker:dind"
      security_context {
        privileged  = true
        run_as_user = "0"
      }
      command = ["dockerd", "--host", "tcp://127.0.0.1:2375"]
      volume_mount {
        name       = "dind-storage"
        mount_path = "/var/lib/docker"
      }
    }

    container {
      name              = "postgres-container"
      image             = "docker.io/marktmilligan/postgres:13"
      image_pull_policy = "Always"
      security_context {
        run_as_user = "999"
      }
      resources {
        requests = {
          cpu    = local.cpu-request
          memory = local.memory-request
        }
        limits = {
          cpu    = local.cpu-limit
          memory = local.memory-limit
        }
      }
      env {
        name  = "PGDATA"
        value = "/var/lib/postgresql/data/k8s"
      }
      volume_mount {
        mount_path = "/var/lib/postgresql/data"
        name       = "postgres-data-directory"
      }
    }
    volume {
      name = "home-directory"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home-directory.metadata.0.name
      }
    }
    volume {
      name = "dind-storage"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.dind.metadata.0.name
        read_only  = false
      }
    }
    volume {
      name = "postgres-data-directory"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.postgres-data-directory.metadata.0.name
      }
    }
  }
}

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
        storage = "10Gi"
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
        storage = "5Gi"
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

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.this.start_count
  resource_id = kubernetes_pod.main[0].id

  item {
    key   = "website url"
    value = local.port_forward_urls["8080"]
  }

  item {
    key   = "api url"
    value = local.port_forward_domains["3000"]
  }

  item {
    key   = "branch url"
    value = "https://github.com/usdigitalresponse/usdr-gost/tree/${data.coder_parameter.git_checkout_branch_name.value}"
  }

  item {
    key   = "main image"
    value = local.main_docker_image
  }

  item {
    key   = "agent id"
    value = coder_agent.coder.id
  }
}
