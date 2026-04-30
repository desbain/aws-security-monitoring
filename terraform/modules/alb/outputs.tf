output "alb_dns_name" {
  value = aws_lb.Portfolio-ALB.dns_name
  description = "The DNS name of the Application Load Balancer"
  
}

output "alb_arn" {
  value = aws_lb.Portfolio-ALB.arn
  description = "The ARN of the Application Load Balancer"
  
}