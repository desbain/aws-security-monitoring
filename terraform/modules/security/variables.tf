variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "cidr_ipv4" {
  description = "The CIDR block for the IP address to allow access"
  type        = string
}