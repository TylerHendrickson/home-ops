terraform {
  required_version = "1.5.7"
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.11.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
  }
}
