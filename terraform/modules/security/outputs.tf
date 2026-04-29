output "alb_sg" {
  value = aws_security_group.alb_sg.id
}

output "bastion_host_sg" {
  value = aws_security_group.bastion_host_sg.id
}

output "rds_sg" {
  value = aws_security_group.rds_sg.id
}