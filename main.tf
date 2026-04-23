module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  aws_region   = var.aws_region
  your_ip      = var.your_ip
}

module "gpu_instance" {
  source = "./modules/gpu-instance"

  project_name      = var.project_name
  instance_type     = var.instance_type
  use_spot          = var.use_spot
  key_pair_name     = var.key_pair_name
  subnet_id         = module.networking.public_subnet_id
  security_group_id = module.networking.security_group_id
  volume_size_gb    = var.volume_size_gb
}