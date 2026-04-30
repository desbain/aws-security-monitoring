output "route53_record_name" {
  value = aws_route53_record.Portfolio-ALB-Record.name
  description = "The fully qualified domain name of the Route 53 record"
}