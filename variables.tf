variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "gpu-k8s-lab"
}

variable "instance_type" {
  type    = string
  default = "g4dn.xlarge" # T4 GPU, cheapest
  # options: g4dn.xlarge (T4/16GB), g5.xlarge (A10G/24GB), p3.2xlarge (V100/16GB)
}

variable "use_spot" {
  type    = bool
  default = true # ~70% cheaper. Set false for stability.
}

variable "key_pair_name" {
  type        = string
  description = "Name of existing AWS key pair for SSH"
}

variable "your_ip" {
  type        = string
  description = "Your IP for SSH access. Format: x.x.x.x/32"
}

variable "volume_size_gb" {
  type    = number
  default = 60 # need space for Docker images + model weights
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile name from ~/.aws/credentials"
  default     = "default"
}