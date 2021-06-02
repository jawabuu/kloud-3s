terraform {
  required_version = ">= 0.12.26"
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "~> 1.5.0"
    }
  }
}