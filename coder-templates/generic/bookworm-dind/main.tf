data "coder_workspace" "this" {}

locals {
  omz_plugins     = jsondecode(data.coder_parameter.oh_my_zsh_plugins.value)
  omz_plugins_cmd = length(local.omz_plugins) > 0 ? "source .zshrc && omz plugin enable ${join(" ", local.omz_plugins)}" : "true"

  cpu-request    = "250m"
  memory-request = "500m"
  cpu-limit      = 3
  memory-limit   = "10G"

  main_docker_image    = "ghcr.io/tortitude/coder-templates:generic-bookworm-dind"
  git_config_auto_user = data.coder_parameter.git_config_auto_user.value == "true"

  git_clone_repo  = data.coder_parameter.git_clone_repo.value
  clone_url       = endswith(local.git_clone_repo, ".git") ? local.git_clone_repo : "git@github.com:${local.git_clone_repo}.git"
  checkout_branch = data.coder_parameter.git_checkout_branch.value
  checkout_base   = data.coder_parameter.git_checkout_base_branch.value
  repo_name       = try(one(regex("^.+\\/(.+)\\.git$", local.clone_url)), "")
  default_working_directory = coalesce(
    data.coder_parameter.default_working_directory.value,
    trimsuffix("${try(one(regex("^.+\\/(.+)\\.git$", local.clone_url)), "")}", "/")
  )
  absolute_default_working_directory = startswith(local.default_working_directory, "/") ? local.default_working_directory : "/home/coder/${local.default_working_directory}"
}

resource "coder_agent" "coder" {
  os   = "linux"
  arch = "amd64"
  dir  = local.absolute_default_working_directory

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

  }

  startup_script_timeout = 300
  startup_script = templatefile("${path.module}/tpl/coder_agent_startup_script.bash", {
    git_config_auto_user_name  = local.git_config_auto_user ? data.coder_workspace.this.owner : ""
    git_config_auto_user_email = local.git_config_auto_user ? data.coder_workspace.this.owner_email : ""
    git_clone_url              = local.git_clone_repo != "" ? local.clone_url : ""
    git_repo_name              = local.repo_name
    git_checkout_branch        = local.checkout_branch
    git_checkout_base          = local.checkout_base
    default_working_directory  = local.absolute_default_working_directory
    preferred_shell            = data.coder_parameter.preferred_shell.value
    oh_my_zsh_plugins_cmd      = local.omz_plugins_cmd
    vscode_extensions          = jsondecode(data.coder_parameter.vscode_extensions.value)
    dotfiles_uri               = "todo"
    git_config_auto_user       = data.coder_parameter.git_config_auto_user.value == "true"
  })
}

# code-server
resource "coder_app" "code-server" {
  agent_id     = coder_agent.coder.id
  slug         = "code-server"
  display_name = "VS Code Web"
  icon         = "/icon/code.svg"
  url          = "http://localhost:13337?folder=${local.absolute_default_working_directory}"
  subdomain    = false
  share        = data.coder_parameter.sharing_mode.value

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }
}

locals {

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
      name              = "main"
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
    name      = "coder-ws-${data.coder_workspace.this.owner}-${data.coder_workspace.this.name}-home"
    namespace = "dev"
  }

  wait_until_bound = false

  spec {
    storage_class_name = "longhorn-coder-workspace"
    access_modes       = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = data.coder_parameter.home_volume_size.value
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
        storage = data.coder_parameter.dind_volume_size.value
      }
    }
  }
}

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.this.start_count
  resource_id = kubernetes_pod.main[0].id

  item {
    key   = "main image"
    value = local.main_docker_image
  }

  item {
    key   = "agent id"
    value = coder_agent.coder.id
  }
}
