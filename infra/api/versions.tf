terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
  # State bucket comes from ../state-bucket.sh. Credentials come from AWS_PROFILE.
  backend "s3" {
    bucket       = "ananda-raj-app-tfstate-ap-south-1"
    key          = "ananda-raj-site/prod/api.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
