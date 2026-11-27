terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.74"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = "test"
  secret_key = "test"

  # LocalStack is fake AWS, so skip checks that need real AWS
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  # Send every AWS call to LocalStack on your laptop
  endpoints {
    s3            = "http://localhost:4566"
    iam           = "http://localhost:4566"
    kms           = "http://localhost:4566"
    sts           = "http://localhost:4566"
    ec2           = "http://localhost:4566"
    cloudwatchlogs = "http://localhost:4566"
    cloudtrail    = "http://localhost:4566"
    organizations = "http://localhost:4566"
  }
}