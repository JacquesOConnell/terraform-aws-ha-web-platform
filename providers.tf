provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.expected_account_id]

  default_tags {
    tags = {
      Project     = "terraform-aws-ha-web-platform"
      Application = "JNIT-HA-Web-Platform"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "JNIT-Cloud-Solutions"
    }
  }
}

provider "aws" {
  alias               = "us_east_1"
  region              = "us-east-1"
  allowed_account_ids = [var.expected_account_id]

  default_tags {
    tags = {
      Project     = "terraform-aws-ha-web-platform"
      Application = "JNIT-HA-Web-Platform"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "JNIT-Cloud-Solutions"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}