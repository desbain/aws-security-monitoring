variable "project_name" {
  description = "The name of the project"
  type        = string
  
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "domain_name" {
  description = "The domain name for the DNS zone"
  type        = string
}

variable "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  type        = string
    
}

variable "alb_zone_id" {
  description = "The hosted zone ID of the Application Load Balancer"
  type        = string
  
}