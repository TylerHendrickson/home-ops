data "coder_workspace" "this" {}
data "coder_git_auth" "github" {
  id = "primary-github"
}

locals {
  git_repo_name        = "grants-ingest"
  coder_home_dir       = "/home/coder"
  localstack_data_dir  = "/var/lib/localstack"
  omz_plugins          = jsondecode(data.coder_parameter.oh_my_zsh_plugins.value)
  git_config_auto_user = data.coder_parameter.git_config_auto_user.value == "true"

  workspace_volume_name_prefix = "coder-ws-${lower(data.coder_workspace.this.owner)}-${lower(data.coder_workspace.this.name)}"
}

resource "coder_agent" "coder" {
  os   = "linux"
  arch = "amd64"
  dir  = "/home/coder/${local.git_repo_name}"

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

  env = {
    GITHUB_TOKEN = data.coder_git_auth.github.access_token
  }

  startup_script_timeout = 300
  startup_script = templatefile("${path.module}/tpl/coder_agent_startup_script.bash", {
    preferred_shell            = data.coder_parameter.preferred_shell.value
    oh_my_zsh_plugins          = join(" ", local.omz_plugins)
    dotfiles_uri               = "todo"
    git_config_auto_user_name  = local.git_config_auto_user ? data.coder_workspace.this.owner : ""
    git_config_auto_user_email = local.git_config_auto_user ? data.coder_workspace.this.owner_email : ""
    git_clone_url              = "git@github.com:usdigitalresponse/${local.git_repo_name}.git"
    git_repo_name              = local.git_repo_name
    git_checkout_branch        = data.coder_parameter.git_checkout_branch_name.value
    git_base_branch            = data.coder_parameter.git_base_branch_name.value
    vscode_extensions          = jsondecode(data.coder_parameter.vscode_extensions.value)
    localstack_data_dir        = local.localstack_data_dir
  })
}

# code-server
resource "coder_app" "code-server" {
  agent_id     = coder_agent.coder.id
  slug         = "code-server"
  display_name = "VS Code Web"
  icon         = "/icon/code.svg"
  url          = "http://localhost:13337?folder=${local.coder_home_dir}/${local.git_repo_name}"
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
  cpu-limit      = "3"
  memory-limit   = "10G"

  main_docker_image = "ghcr.io/tortitude/coder-templates:grants-ingest-feature-development"
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
        name  = "AWS_ACCESS_KEY_ID"
        value = "test"
      }
      env {
        name  = "AWS_SECRET_ACCESS_KEY"
        value = "test"
      }
      env {
        name  = "AWS_SDK_LOAD_CONFIG"
        value = "true"
      }
      env {
        name  = "S3_HOSTNAME"
        value = "localhost"
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

    volume {
      name = "home-directory"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home-directory.metadata[0].name
      }
    }
    volume {
      name = "dind-storage"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.dind.metadata[0].name
        read_only  = false
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "home-directory" {
  metadata {
    name      = "${local.workspace_volume_name_prefix}-home"
    namespace = "dev"
  }

  wait_until_bound = false

  spec {
    storage_class_name = "longhorn-coder-workspace-v2"
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
    name      = "${local.workspace_volume_name_prefix}-dind"
    namespace = "dev"
  }

  wait_until_bound = false

  spec {
    storage_class_name = "longhorn-coder-workspace-v2"
    access_modes       = ["ReadWriteOnce"]
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
    key   = "branch url"
    value = "https://github.com/usdigitalresponse/${local.git_repo_name}/tree/${data.coder_parameter.git_checkout_branch_name.value}"
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
