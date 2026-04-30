variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "account_id" {
  description = "The AWS account ID"
  type        = string
}

variable "sns_email" {
  description = "The email address for SNS notifications"
  type        = string
  
}

variable "region" {
  description = "The AWS region"
  type        = string
}