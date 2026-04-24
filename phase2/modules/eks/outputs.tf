output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_ca_cert" {
  value = aws_eks_cluster.main.certificate_authority[0].data
}

output "node_group_status" {
  value = aws_eks_node_group.gpu.status
}
