terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.33.0"
    }
  }
}

provider "aws" {
  # Configuration options
  region = var.aws_region
  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = "Development"
      Project     = "AWS-UG-ASG-Lifecycle-Hook-Demo"
    }
  }
}