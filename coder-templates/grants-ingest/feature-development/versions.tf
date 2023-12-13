terraform {
  required_version = "1.5.7"
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.12.4"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
  }
}
