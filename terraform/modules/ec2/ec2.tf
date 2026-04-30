#Creating EC2  bastion instance-------------------------------------------------------------
resource "aws_instance" "bastion_host" {
  ami           = var.ami_id
  instance_type = var.instance_type
  iam_instance_profile = var.instance_profile_name # IAM instance profile for the EC2 instance
   key_name      = var.key_name
  subnet_id     = var.public_subnet_ids[0] # Assuming the first public subnet is used for the bastion host
  vpc_security_group_ids = [var.bastion_host_sg] # Security group for the bastion host 
  tags = {
    Name = "${var.project_name}-${var.environment}-bastion-host"
  }
}

#Creating EC2 launch template for portfolio application instances-------------------------------------------------------------

resource "aws_launch_template" "portfolio_launch_template" {
  name = "${var.project_name}-${var.environment}-portfolio-launch-template"
  image_id = var.ami_id
  instance_type = var.instance_type
  key_name = var.key_name
  
    iam_instance_profile {
    name = var.instance_profile_name
  }

  network_interfaces {
    security_groups = [var.bastion_host_sg] # Security group for launch template instances
  }


    tags = {
      Name = "${var.project_name}-${var.environment}-portfolio-launch-template"
    }
  }

