# modules/gpu-instance/outputs.tf

output "instance_id" {
  value = aws_instance.gpu_node.id
}

output "public_ip" {
  value = aws_instance.gpu_node.public_ip
}

output "public_dns" {
  value = aws_instance.gpu_node.public_dns
}

output "ami_used" {
  value = data.aws_ami.ubuntu_22.id
}