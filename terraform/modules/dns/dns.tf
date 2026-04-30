# Creating data source for Route 53 hosted zone-------------------------------------------------------------
data "aws_route53_zone" "main" {
    name         = var.domain_name
  private_zone = false
}

#Creating Route 53 record for ALB-------------------------------------------------------------
resource "aws_route53_record" "Portfolio-ALB-Record" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}