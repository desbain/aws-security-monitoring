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