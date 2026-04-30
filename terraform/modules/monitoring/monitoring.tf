# Creating guardduty detector-------------------------------------------------------------
resource "aws_guardduty_detector" "Portfolio-GuardDuty-Detector" {
  enable = true

   
   tags = {
    Name = "${var.project_name}-${var.environment}-Portfolio_GuardDuty_Detector"
    }
}

#Creaing SNS topic for GuardDuty-------------------------------------------------------------
resource "aws_sns_topic" "security_alerts" {
  name = "${var.project_name}-${var.environment}-security-alerts"

    tags = {
        Name = "${var.project_name}-${var.environment}-security-alerts"
        }
}

#Creating SNS topic subscription for GuardDuty-------------------------------------------------------------
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.sns_email
}

#Creating EventBridge rule and target for GuardDuty findings-----------------------------------------------------------

resource "aws_cloudwatch_event_rule" "guardduty" {
  name        = "${var.project_name}-${var.environment}-GuardDuty-Rule"
 description = "Route GuardDuty findings to SNS and Lambda"

  event_pattern = jsonencode({
    source = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-GuardDuty-Rule"
  }
}

# EventBridge target — SNS--------------------------------------------------------------
resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.guardduty.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}

#Creating lambda role for GuardDuty findings-------------------------------------------------------------
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

#Creating lambda function for GuardDuty findings------------------------------------------------------------
resource "aws_lambda_function" "example" {
  filename      = "${path.module}/lambda/guardduty_isolate_ec2.zip"
  function_name = "${var.project_name}-${var.environment}-GuardDuty-Isolate-EC2"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime = "python3.12"

  tags = {
    Name = "${var.project_name}-${var.environment}-guardduty-isolate-ec2"
  }
 
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda/guardduty_isolate_ec2.zip"
}