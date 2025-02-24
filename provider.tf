terraform {
required_version = ">= 1.3.0, < 2.0.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.20.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}