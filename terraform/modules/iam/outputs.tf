output "instance_profile_name" {
    value = aws_iam_instance_profile.ec2_profile.name
    }

output "rds_role_name" {
    value = aws_iam_role.rds.arn
    }