variable "project_name" {
  description = "The name of the project"
  type        = string
  
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs for private subnets"
  type        = list(string)
}

variable "rds_sg" {
  description = "The security group ID for the RDS instance"
  type        = string
}

variable "rds_role_name" {
  description = "The name of the IAM role for RDS"
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
  sensitive = true
}