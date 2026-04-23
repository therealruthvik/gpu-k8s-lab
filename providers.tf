terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: use S3 backend for state (recommended)
  # backend "s3" {
  #   bucket = "your-tfstate-bucket"
  #   key    = "gpu-k8s-lab/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "gpu-k8s-lab"
      ManagedBy = "terraform"
      Owner     = "ruthvik"
    }
  }
}