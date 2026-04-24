output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region} --profile ${var.aws_profile}"
}

output "grafana_access" {
  value     = "http://<node-external-ip>:32000  (user: admin, pass: ${var.grafana_password})"
  sensitive = true
}

output "vllm_nodeport_command" {
  value = "kubectl get svc vllm -n vllm -o jsonpath='{.spec.ports[0].nodePort}'"
}
