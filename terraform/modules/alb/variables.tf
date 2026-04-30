variable "project_name" {
  description = "The name of the project"
  type        = string
  
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "The IDs of the public subnets"
  type        = list(string)
}

variable "alb_sg" {
  description = "The ID of the security group for the ALB"
  type        = string
  
}

variable "launch_template_id" {
  description = "The ID of the launch template for the EC2 instances"
  type        = string
  
}

variable "certificate_arn" {
  description = "The ARN of the ACM certificate for the ALB"
  type        = string
  
}

variable "ssl_policy" {
  description = "SSL policy for the ALB HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-2016-08"
}