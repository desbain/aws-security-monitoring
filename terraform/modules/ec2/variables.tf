variable "project_name" {
  description = "The name of the project"
  type        = string
 }

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "public_subnet_ids" {
  description = "The IDs of the public subnets"
  type        = list(string)
}

variable "bastion_host_sg" {
  description = "security group for bastion host"
  type = string
}

variable "instance_profile_name" {
  description = "The name of the EC2 instance profile"
  type = string
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
  type = string
}