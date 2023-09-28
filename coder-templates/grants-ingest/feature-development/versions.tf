terraform {
  required_version = "1.5.6"
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.12.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
  }
}
