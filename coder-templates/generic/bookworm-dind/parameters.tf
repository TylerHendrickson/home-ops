data "coder_parameter" "git_clone_repo" {
  name        = "Git: Clone Repo"
  description = "The git repo to clone (URL or GitHub `org/repo`)."
  order       = 10
  type        = "string"
  default     = ""
  mutable     = true
}

data "coder_parameter" "git_checkout_branch" {
  name        = "Git: Checkout Branch"
  description = "The branch to check out. This will be created if it does not already exist."
  order       = 11
  type        = "string"
  default     = "main"
  mutable     = true
}

data "coder_parameter" "git_checkout_base_branch" {
  name        = "Git: Checkout Branch Base"
  description = "The starting point when checking out a new branch."
  order       = 12
  type        = "string"
  mutable     = true
  default     = "main"
}

data "coder_parameter" "default_working_directory" {
  name        = "Default Working Directory"
  description = "The default directory (absolute or relative to `/home/coder`) to target when launching terminals and IDEs. Empty value defaults to \"Git: Clone Repo\" if set, else `/home/coder`. Will be created if it does not exist at startup, along with intermediary directories."
  order       = 18
  type        = "string"
  default     = ""
  mutable     = true
}

data "coder_parameter" "git_config_auto_user" {
  name        = "Git Config: Auto-populate `git config --global user.name` and `user.email`?"
  description = "If not selected, you will have to configure these before you can commit."
  order       = 19
  type        = "bool"
  default     = "false"
  mutable     = false
}

data "coder_parameter" "home_volume_size" {
  name        = "Home Disk Size"
  description = "Amount of storage to allocate for the home directory volume. Can only be increased after creation!"
  order       = 20
  type        = "string"
  default     = "10Gi"
  mutable     = true
}

data "coder_parameter" "dind_volume_size" {
  name        = "Docker-in-Docker Disk Size"
  description = "Amount of storage to allocate for the Docker-in-Docker volume. Can only be increased after creation!"
  order       = 21
  type        = "string"
  default     = "5Gi"
  mutable     = true
}

data "coder_parameter" "preferred_shell" {
  name        = "Preferred shell"
  description = "What command-line shell do you want to use?"
  order       = 30
  type        = "string"
  mutable     = true
  default     = "zsh"

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
  order       = 31
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
  order       = 32
  type        = "list(string)"
  mutable     = true
  default = jsonencode([
    "ms-azuretools.vscode-docker",
    "hashicorp.terraform",
    "4ops.terraform",
    "task.vscode-task",
  ])
}

data "coder_parameter" "sharing_mode" {
  name        = "Enable Shared Access"
  description = "Whether to enable access for other team members."
  order       = 99
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
