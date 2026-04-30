# Create DB subnet group for RDS-------------------------------------------------------------
resource "aws_db_subnet_group" "RDS-subnet-group" {
  name       = "${var.project_name}-${var.environment}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-subnet-group"
  }
}

# Create RDS instance-------------------------------------------------------------
resource "aws_db_instance" "rds-instance" {
  identifier          = "${var.project_name}-${var.environment}-rds-instance"
  db_name              = var.db_name
  engine               = "postgres"
  engine_version       = "16"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  username             = var.db_username
  password             = var.db_password
    vpc_security_group_ids = [var.rds_sg]
    db_subnet_group_name = aws_db_subnet_group.RDS-subnet-group.name
    deletion_protection = false
  skip_final_snapshot  = true
  monitoring_role_arn = var.rds_role_name
  monitoring_interval = 60

    tags = {
        Name = "${var.project_name}-${var.environment}-rds-instance"
    }
}