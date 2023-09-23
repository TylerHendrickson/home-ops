terraform {
  required_version = "1.5.4"
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.12.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
  }
}
