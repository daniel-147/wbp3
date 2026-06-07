terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Bucket and lock table are created by bootstrap. Backend blocks can't use
  # variables, so these are hardcoded.
  backend "s3" {
    bucket         = "wbp3-tfstate-pipeline-poc"
    key            = "wbp3/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "wbp3-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "wbp3"
      ManagedBy = "terraform"
    }
  }
}
