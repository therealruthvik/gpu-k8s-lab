# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.project_name}-vpc" }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-subnet" }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "gpu_node" {
  name        = "${var.project_name}-gpu-sg"
  description = "GPU k3s node security group"
  vpc_id      = aws_vpc.main.id

  # SSH
ingress {
  from_port        = 22
  to_port          = 22
  protocol         = "tcp"
  cidr_blocks      = local.ipv4_cidr       # ← was [var.your_ip]
  ipv6_cidr_blocks = local.ipv6_cidr       # ← new
  description      = "SSH from admin"
}

# Kubernetes API
ingress {
  from_port        = 6443
  to_port          = 6443
  protocol         = "tcp"
  cidr_blocks      = local.ipv4_cidr
  ipv6_cidr_blocks = local.ipv6_cidr
  description      = "k3s API server"
}

# NodePort
ingress {
  from_port        = 30000
  to_port          = 32767
  protocol         = "tcp"
  cidr_blocks      = local.ipv4_cidr
  ipv6_cidr_blocks = local.ipv6_cidr
  description      = "Kubernetes NodePort services"
}

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-gpu-sg" }
}

locals {
  is_ipv6   = can(regex(":", var.your_ip))          # IPv6 contains ":"
  ipv4_cidr = local.is_ipv6 ? [] : [var.your_ip]
  ipv6_cidr = local.is_ipv6 ? [var.your_ip] : []
}