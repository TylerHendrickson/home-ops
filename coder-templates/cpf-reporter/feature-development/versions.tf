terraform {
  required_version = "1.6.6"
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.12.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
  }
}
