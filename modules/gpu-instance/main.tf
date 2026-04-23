# Fetch latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu_22" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM Role for EC2 (SSM access + describe self)
resource "aws_iam_role" "gpu_node" {
  name = "${var.project_name}-gpu-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.gpu_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "gpu_node" {
  name = "${var.project_name}-gpu-node-profile"
  role = aws_iam_role.gpu_node.name
}

# Bootstrap script rendered with variables
locals {
  user_data = file("${path.root}/scripts/bootstrap.sh")
}

# EC2 Instance
resource "aws_instance" "gpu_node" {
  ami                    = data.aws_ami.ubuntu_22.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name = aws_key_pair.gpu_node.key_name
  iam_instance_profile   = aws_iam_instance_profile.gpu_node.name

  # Spot instance config
  dynamic "instance_market_options" {
    for_each = var.use_spot ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        instance_interruption_behavior = "terminate"
      }
    }
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.volume_size_gb
    encrypted   = true

    tags = { Name = "${var.project_name}-root-vol" }
  }

  user_data                   = local.user_data
  user_data_replace_on_change = true  # re-run bootstrap if script changes

  tags = { Name = "${var.project_name}-gpu-node" }

  # Wait for instance to be fully initialized
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_key_pair" "gpu_node" {
  key_name   = "${var.project_name}-key"
  public_key = file("~/.ssh/mlops.pub")   # path to your public key
}