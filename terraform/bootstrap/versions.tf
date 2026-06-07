terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Local state on purpose — this config creates the bucket the main config
  # then uses as its backend, so it can't store its own state there.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "wbp3"
      ManagedBy = "terraform-bootstrap"
    }
  }
}
