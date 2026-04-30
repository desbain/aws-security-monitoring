# # Creating Application Load Balancer security group-------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "allow_http and https"
  description = "Allow HTTP and HTTPS inbound traffic and all outbound traffic"
  vpc_id      = var.vpc_id

    tags = {
        Name = "${var.project_name}-${var.environment}-alb-sg"
    }

}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.alb_sg.id
    cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_ipv4" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports

}

 # Creating Bastion security group-------------------------------------------------------

resource "aws_security_group" "bastion_host_sg" {
  name        = "allow_SSH"
  description = "Allow SSH inbound traffic and all outbound traffic"
  vpc_id      = var.vpc_id

    tags = {
        Name = "${var.project_name}-${var.environment}-bastion-host-sg"
    }

}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.bastion_host_sg.id
    cidr_ipv4 = var.cidr_ipv4  # /32 means exactly one IP
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}


resource "aws_vpc_security_group_egress_rule" "bastion_egress" {
  security_group_id = aws_security_group.bastion_host_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports

}

# Creating RDS security group-------------------------------------------------------

resource "aws_security_group" "rds_sg" {
  name        = "allow_PostgreSQL"
  description = "Allow PostgreSQL inbound traffic and all outbound traffic"
  vpc_id      = var.vpc_id

    tags = {
        Name = "${var.project_name}-${var.environment}-rds-sg"
    }

}

resource "aws_vpc_security_group_ingress_rule" "allow_postgresql" {
  security_group_id = aws_security_group.rds_sg.id
  referenced_security_group_id = aws_security_group.bastion_host_sg.id
  from_port         = 5432
  ip_protocol       = "tcp"
  to_port           = 5432# Allow access from the bastion host security group to the RDS security group
}


resource "aws_vpc_security_group_egress_rule" "rds_all_egress" {
  security_group_id = aws_security_group.rds_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports

}

# Creating App security group-------------------------------------------------------
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-${var.environment}-app-sg"
  description = "Allow HTTP from ALB and SSH from bastion"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-app-sg"
  }
}

# Allow HTTP from ALB
resource "aws_vpc_security_group_ingress_rule" "allow_http_from_alb" {
  security_group_id            = aws_security_group.app_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80
}

# Allow SSH from bastion
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_from_bastion" {
  security_group_id            = aws_security_group.app_sg.id
  referenced_security_group_id = aws_security_group.bastion_host_sg.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}

# Allow all outbound
resource "aws_vpc_security_group_egress_rule" "app_egress" {
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}