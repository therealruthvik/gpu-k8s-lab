# gpu-k8s-lab

Two-phase GPU Kubernetes lab on AWS, provisioned with Terraform.

| | Phase 1 | Phase 2 |
|---|---|---|
| **Cluster** | k3s (single EC2) | EKS (managed) |
| **Workload** | bare GPU access | vLLM + Llama-3.1-8B |
| **Observability** | none | Prometheus + Grafana + DCGM |
| **Cost** | ~$0.16/hr spot | ~$0.29/hr (EKS + spot) |

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

---

## Phase 2 — EKS + vLLM + Observability

### What gets created

- EKS 1.31 cluster with g4dn.xlarge spot node group (AL2 GPU AMI — NVIDIA drivers pre-installed)
- NVIDIA GPU Operator (`driver.enabled=false` — drivers already on AMI)
- kube-prometheus-stack (Prometheus + Grafana) with DCGM dashboard auto-imported
- vLLM serving `meta-llama/Llama-3.1-8B-Instruct` on NodePort 31000
- Grafana on NodePort 32000

### Additional prerequisites

- AWS Service Quota: **Running Spot G and VT instances** ≥ 4 in target region
- HuggingFace account with Llama 3.1 license accepted at `huggingface.co/meta-llama/Llama-3.1-8B-Instruct`
- HuggingFace token (read scope) from `huggingface.co/settings/tokens`

### Deploy

```bash
cd phase2
cp terraform.tfvars.example terraform.tfvars
# fill in your_ip, hf_token, aws_profile

terraform init
terraform apply   # ~25 min: EKS ~15min + node group ~5min + helm releases ~5min
```

### Wire kubeconfig and deploy vLLM

```bash
# After terraform apply completes:
aws eks update-kubeconfig --name gpu-k8s-lab --region <region> --profile <profile>

# Apply vLLM manifests (not managed by Terraform — iterate freely)
kubectl apply -f manifests/vllm-deployment.yaml
kubectl apply -f manifests/vllm-service.yaml

# Watch vLLM pod start (model download takes ~10 min)
kubectl logs -n vllm -l app=vllm -f
```

### Verify GPU

```bash
# GPU visible to Kubernetes
kubectl get nodes -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu'

# GPU Operator pods healthy
kubectl get pods -n gpu-operator
```

### Load test → watch DCGM_FI_DEV_GPU_UTIL spike

```bash
chmod +x phase2/scripts/load-test.sh
./phase2/scripts/load-test.sh 30   # 30 concurrent requests
```

Open Grafana at `http://<node-external-ip>:32000` → NVIDIA DCGM Exporter Dashboard → GPU Utilization.

Get node IP:
```bash
kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}'
```

### Phase 2 architecture

```
phase2/
├── main.tf                      — EKS module + GPU Operator + Prometheus helm releases
├── modules/
│   ├── networking/              — VPC with 2 public subnets across AZs (EKS requirement)
│   └── eks/                     — EKS cluster + AL2 GPU spot node group + IAM
└── manifests/
    ├── vllm-deployment.yaml     — vLLM pod with GPU limit + HF token mount
    └── vllm-service.yaml        — NodePort 31000
```

DCGM metrics flow: GPU Operator DCGM exporter → ServiceMonitor → Prometheus → Grafana dashboard `gnetId: 12239`.

### Destroy

```bash
cd phase2
terraform destroy
```
