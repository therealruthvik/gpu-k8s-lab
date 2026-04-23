#!/bin/bash
set -euo pipefail
exec > /var/log/bootstrap.log 2>&1

echo "=== Bootstrap started at $(date) ==="

# 1. System update
apt-get update -y
apt-get install -y curl wget git jq

# 2. Install k3s (disable traefik, use containerd)
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --disable servicelb

# 3. Wait for k3s to be ready
echo "Waiting for k3s..."
until kubectl get nodes 2>/dev/null | grep -q "Ready"; do
  sleep 5
done
echo "k3s ready"

# 4. Setup kubeconfig for ubuntu user
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
echo 'export KUBECONFIG=/home/ubuntu/.kube/config' >> /home/ubuntu/.bashrc

# 5. Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 6. Install NVIDIA GPU Operator
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update

kubectl create namespace gpu-operator || true

helm install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --create-namespace \
  --set driver.enabled=true \
  --set toolkit.enabled=true \
  --set devicePlugin.enabled=true \
  --set dcgmExporter.enabled=true \
  --set migManager.enabled=false \
  --set toolkit.env[0].name=CONTAINERD_CONFIG \
  --set toolkit.env[0].value=/var/lib/rancher/k3s/agent/etc/containerd/config.toml \
  --set toolkit.env[1].name=CONTAINERD_SOCKET \
  --set toolkit.env[1].value=/run/k3s/containerd/containerd.sock \
  --set toolkit.env[2].name=CONTAINERD_RUNTIME_CLASS \
  --set toolkit.env[2].value=nvidia \
  --set toolkit.env[3].name=CONTAINERD_SET_AS_DEFAULT \
  --set-string toolkit.env[3].value="true"

echo "=== Bootstrap complete at $(date) ==="
echo "GPU Operator installed. Check: kubectl get pods -n gpu-operator"