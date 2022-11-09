#Defining the provider on which we have to create infrastructure - AWS
provider "aws" {
  region = "us-west-2"
  access_key = ""
  secret_key = ""
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.0"
    }
  }
}