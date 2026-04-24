variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type    = string
  default = "default"
}

variable "project_name" {
  type    = string
  default = "gpu-k8s-lab-p2"
}

variable "cluster_name" {
  type    = string
  default = "gpu-k8s-lab"
}

variable "instance_type" {
  type    = string
  default = "g4dn.xlarge" # T4/16GB — cheapest GPU spot on EKS
}

variable "your_ip" {
  type        = string
  description = "Your IPv4 with /32 suffix for NodePort access. Get: curl -4 ifconfig.me"
}

variable "hf_token" {
  type        = string
  sensitive   = true
  description = "HuggingFace token (read scope). Required to pull Llama-3.1-8B-Instruct"
}

variable "model_id" {
  type    = string
  default = "meta-llama/Llama-3.1-8B-Instruct"
}

variable "grafana_password" {
  type      = string
  sensitive = true
  default   = "admin123" # change before exposing publicly
}
