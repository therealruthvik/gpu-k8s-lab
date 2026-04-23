output "instance_id" {
  value = module.gpu_instance.instance_id
}

output "public_ip" {
  value       = module.gpu_instance.public_ip
  description = "SSH: ssh -i your-key.pem ubuntu@<this_ip>"
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${module.gpu_instance.public_ip}"
}

output "bootstrap_log_command" {
  value = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${module.gpu_instance.public_ip} 'tail -f /var/log/bootstrap.log'"
}