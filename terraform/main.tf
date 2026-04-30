terraform {
  backend "s3" {
    bucket  = "portfolio-terraform-state-905418310734"
    key     = "dev/terraform.tfstate"
    region  = "us-east-2"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}


module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "security" {
  source       = "./modules/security"
  vpc_id       = module.vpc.vpc_id
  project_name = var.project_name
  environment  = var.environment
  cidr_ipv4    = var.cidr_ipv4
}

module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  environment  = var.environment
}

module "rds" {
  source             = "./modules/rds"
  project_name       = var.project_name
  environment        = var.environment
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
  rds_sg             = module.security.rds_sg
  rds_role_name      = module.iam.rds_role_name
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "ec2" {
  source                = "./modules/ec2"
  project_name          = var.project_name
  environment           = var.environment
  instance_profile_name = module.iam.instance_profile_name
  ami_id                = var.ami_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  bastion_host_sg       = module.security.bastion_host_sg
  instance_type         = var.instance_type
  key_name              = var.key_name
   db_endpoint = module.rds.rds_db_endpoint
    db_password = var.db_password
  app_sg = module.security.app_sg
}
}

module "alb" {
  source = "./modules/alb"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  alb_sg             = module.security.alb_sg
  certificate_arn    = var.certificate_arn
  launch_template_id = module.ec2.launch_template_id
}

module "dns" {
  source = "./modules/dns"

  project_name = var.project_name
  environment  = var.environment
  domain_name  = var.domain_name
  alb_dns_name = module.alb.alb_dns_name
  alb_zone_id  = module.alb.alb_zone_id
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name = var.project_name
  environment  = var.environment
  account_id   = var.account_id
  sns_email    = var.sns_email
  region       = var.aws_region
}