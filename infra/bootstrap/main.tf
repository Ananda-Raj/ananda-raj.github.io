# One-time setup: the S3 bucket that holds Terraform state for the site API.

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
      Component   = "tfstate"
    }
  }
}

data "aws_caller_identity" "current" {}

module "state_bucket" {
  source                  = "../modules/tfstate-bucket"
  bucket_name             = "${var.project}-${var.environment}-tfstate-${data.aws_caller_identity.current.account_id}"
  noncurrent_version_days = var.noncurrent_state_days
}
