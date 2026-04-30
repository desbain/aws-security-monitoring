output "rds_db_name" {
  value = aws_db_instance.rds-instance.db_name
  description = "The name of the RDS database"
}

output "rds_db_endpoint" {
  value = aws_db_instance.rds-instance.endpoint
  description = "The endpoint of the RDS database"
}