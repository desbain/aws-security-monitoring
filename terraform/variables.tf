variable "project_name" {
  description = "The name of the project"
  type        = string

}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}


variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "The availability zones to use for subnets"
  type        = list(string)

}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "cidr_ipv4" {
  description = "The CIDR block for the IP address to allow access"
  type        = string
}

variable "db_name" {
  description = "The name of the RDS database"
  type        = string
}

variable "db_username" {
  description = "The username for the RDS database"
  type        = string
}

variable "db_password" {
  description = "The password for the RDS database"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "The instance type for the EC2 instance"
  type        = string
}

variable "key_name" {
  description = "The name of the EC2 key pair"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instance"
  type        = string
}


variable "certificate_arn" {
  description = "The ARN of the ACM certificate for the ALB"
  type        = string

}

variable "domain_name" {
  description = "The domain name for the portfolio"
  type        = string
}

variable "sns_email" {
  description = "Email address for security alerts"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}