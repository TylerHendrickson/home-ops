data "coder_parameter" "sharing_mode" {
  name        = "Enable Shared Access"
  description = "Whether to enable access for other team members."
  type        = "string"
  default     = "authenticated"

  option {
    name  = "Enabled"
    value = "authenticated"
  }

  option {
    name  = "Disabled"
    value = "owner"
  }
}

data "coder_parameter" "git_config_auto_user" {
  name        = "Git Config: Auto-populate `git config --global user.name` and `user.email`?"
  description = "If not selected, you will have to configure these before you can commit."
  type        = "bool"
  default     = "false"
}

data "coder_parameter" "home_volume_size" {
  name        = "Home Disk Size"
  description = "Amount of storage to allocate for the home directory volume. Can only be increased after creation!"
  type        = "string"
  default     = "10Gi"
}

data "coder_parameter" "dind_volume_size" {
  name        = "Docker-in-Docker Disk Size"
  description = "Amount of storage to allocate for the Docker-in-Docker volume. Can only be increased after creation!"
  type        = "string"
  default     = "5Gi"
}

data "coder_parameter" "preferred_shell" {
  name        = "Preferred shell"
  description = "What command-line shell do you want to use?"
  type        = "string"
  mutable     = true
  default     = "bash"

  option {
    name  = "bash"
    value = "bash"
  }

  option {
    name  = "zsh"
    value = "zsh"
  }
}

data "coder_parameter" "oh_my_zsh_plugins" {
  name        = "Preferred shell: Oh My Zsh plugins"
  description = "Select [plugins](https://github.com/ohmyzsh/ohmyzsh/wiki/Plugins) to enable for [Oh My ZSH](https://ohmyz.sh/). Only effective if zsh is the preferred shell."
  type        = "list(string)"
  mutable     = true
  default = jsonencode([
    "aws",
    "docker",
    "docker-compose",
    "extract",
    "fd",
    "git",
    "npm",
    "nvm",
    "postgres",
    "pre-commit",
    "ripgrep",
    "terraform",
    "themes",
    "wd",
    "yarn",
  ])
}

data "coder_parameter" "vscode_extensions" {
  name        = "VS Code Extensions"
  description = "Identify [Visual Studio Code marketplace](https://marketplace.visualstudio.com/vscode) extensions to install."
  type        = "list(string)"
  mutable     = true
  default = jsonencode([
    "ms-azuretools.vscode-docker",
    "hashicorp.terraform",
    "4ops.terraform",
    "task.vscode-task",
  ])
}
