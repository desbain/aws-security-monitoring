# Create Application Load Balancer-------------------------------------------------------------
resource "aws_lb" "Portfolio-ALB" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg]
  subnets            = var.public_subnet_ids
  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }

}

# Create target group for ALB-------------------------------------------------------------
resource "aws_lb_target_group" "Portfolio-ALB-TG" {
  name        = "${var.project_name}-${var.environment}-alb-tg"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

    health_check {
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 5
        interval            = 30
        path                = "/health"
        protocol            = "HTTP"
    }
}

# Create listener for ALB-------------------------------------------------------------
resource "aws_lb_listener" "Portofilio-ALB-Listener" {
  load_balancer_arn = aws_lb.Portfolio-ALB.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.Portfolio-ALB-TG.arn
  }
}

# Create listener for HTTP-HTTPS-----------------------------------------------------
resource "aws_lb_listener" "Portofilio" {
  load_balancer_arn = aws_lb.Portfolio-ALB.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "redirect"
    
    redirect {
       port = "443"
       protocol = "HTTPS"
       status_code = "HTTP_301"
    }
  }
}

#Create an Auto Scaling Group for the Portfolio application
resource "aws_autoscaling_group" "Portfolio-ASG" {
  name               = "${var.project_name}-${var.environment}-asg"
  vpc_zone_identifier = var.public_subnet_ids
  desired_capacity   = 2
  max_size           = 4
  min_size           = 1
   target_group_arns   = [aws_lb_target_group.Portfolio-ALB-TG.arn]

  launch_template {
    id      = var.launch_template_id
    version = "$Latest"
     
  }
}

