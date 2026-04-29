terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"
}

module "vpc" {
  source = "./modules/vpc"

  project_name          = var.project_name
  environment           = var.environment
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  availability_zones    = var.availability_zones
}

module "security" {
  source = "./modules/security"

  vpc_id = module.vpc.vpc_id
  project_name = var.project_name
  environment = var.environment
    cidr_ipv4 = var.cidr_ipv4
}

module "iam" {
  source = "./modules/iam"
  project_name = var.project_name
  environment = var.environment
}