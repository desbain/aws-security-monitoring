output "bastion_public_ip" {
  value = aws_instance.bastion_host.public_ip
  description = "The public IP address of the bastion host"
  
}

output "launch_template_id" {
  value = aws_launch_template.portfolio_launch_template.id
  description = "The ID of the portfolio launch template"
  
}