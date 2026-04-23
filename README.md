# gpu-k8s-lab

Single-node GPU Kubernetes cluster on AWS EC2, provisioned with Terraform. Runs k3s with NVIDIA GPU Operator — ready for ML workloads in ~15 minutes.

## What gets created

- VPC with public subnet, internet gateway, security group (SSH + k3s API + NodePorts)
- EC2 GPU instance (spot by default, ~70% cost reduction)
- IAM role with SSM access
- k3s installed with traefik/servicelb disabled
- NVIDIA GPU Operator via Helm (driver + toolkit + device plugin + DCGM exporter)

## Prerequisites

- Terraform >= 1.6
- AWS CLI configured with a named profile
- SSH key pair at `~/.ssh/<key_pair_name>.pem` and `~/.ssh/<key_pair_name>.pub`
- AWS Service Quota for **Running On-Demand G and VT instances** (or Spot equivalent) > 0
  - Request at: AWS Console → Service Quotas → EC2 → "G and VT instances" → set to 4+

## Quick start

```bash
# 1. Clone
git clone https://github.com/<you>/gpu-k8s-lab.git
cd gpu-k8s-lab

# 2. Configure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set your_ip, key_pair_name, aws_profile

# 3. Get your IPv4 address (use /32 suffix)
curl -4 ifconfig.me

# 4. Deploy
terraform init
terraform apply
```

## Variables (`terraform.tfvars`)

| Variable | Required | Notes |
|---|---|---|
| `your_ip` | yes | IPv4 with `/32` suffix — `curl -4 ifconfig.me` |
| `key_pair_name` | yes | Name of key in `~/.ssh/` (no extension) |
| `aws_profile` | yes | Profile from `~/.aws/credentials` |
| `aws_region` | no | Default: `us-east-1` |
| `instance_type` | no | `g4dn.xlarge` (T4/16GB), `g5.xlarge` (A10G/24GB), `p3.2xlarge` (V100/16GB) |
| `use_spot` | no | Default: `true`. Set `false` for stability |
| `volume_size_gb` | no | Default: `60` |

## Usage

```bash
# SSH into instance
ssh -i ~/.ssh/<key_pair_name>.pem ubuntu@$(terraform output -raw public_ip)

# Watch bootstrap (GPU Operator install takes ~15 min)
ssh -i ~/.ssh/<key_pair_name>.pem ubuntu@$(terraform output -raw public_ip) 'tail -f /var/log/bootstrap.log'

# Verify GPU is visible to Kubernetes
kubectl get nodes -o wide
kubectl describe node | grep nvidia.com/gpu

# Destroy when done
terraform destroy
```

## Architecture

```
main.tf
├── modules/networking   — VPC, subnet (10.0.1.0/24), IGW, security group
└── modules/gpu-instance — IAM role, AMI lookup, EC2 (spot), bootstrap via user-data
```

Bootstrap (`scripts/bootstrap.sh`) runs at instance launch and logs to `/var/log/bootstrap.log`.

## Cost

| Instance | GPU | On-demand | Spot (approx) |
|---|---|---|---|
| g4dn.xlarge | T4 16GB | ~$0.53/hr | ~$0.16/hr |
| g5.xlarge | A10G 24GB | ~$1.01/hr | ~$0.30/hr |
| p3.2xlarge | V100 16GB | ~$3.06/hr | ~$0.92/hr |

**Always run `terraform destroy` when done.** Spot instances can be interrupted but idle ones still cost money.

## State

State is stored locally (`terraform.tfstate`). For shared/persistent use, enable the S3 backend in `providers.tf`.
