module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
  cluster_name = var.cluster_name
  aws_region   = var.aws_region
  your_ip      = var.your_ip
}

module "eks" {
  source        = "./modules/eks"
  cluster_name  = var.cluster_name
  instance_type = var.instance_type
  subnet_ids    = module.networking.public_subnet_ids
}

# ── Namespaces ────────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "gpu_operator" {
  metadata { name = "gpu-operator" }
  depends_on = [module.eks]
}

resource "kubernetes_namespace" "monitoring" {
  metadata { name = "monitoring" }
  depends_on = [module.eks]
}

resource "kubernetes_namespace" "vllm" {
  metadata { name = "vllm" }
  depends_on = [module.eks]
}

# ── NVIDIA GPU Operator ───────────────────────────────────────────────────────
# driver.enabled=false: EKS AL2 GPU AMI ships NVIDIA drivers pre-installed

resource "helm_release" "gpu_operator" {
  name       = "gpu-operator"
  namespace  = kubernetes_namespace.gpu_operator.metadata[0].name
  repository = "https://helm.ngc.nvidia.com/nvidia"
  chart      = "gpu-operator"
  version    = "v24.9.0"
  timeout    = 600

  set {
    name  = "driver.enabled"
    value = "false"
  }
  set {
    name  = "toolkit.enabled"
    value = "true"
  }
  set {
    name  = "devicePlugin.enabled"
    value = "true"
  }
  set {
    name  = "dcgmExporter.enabled"
    value = "true"
  }
  set {
    name  = "dcgmExporter.serviceMonitor.enabled"
    value = "true"
  }
  set {
    name  = "migManager.enabled"
    value = "false"
  }

  depends_on = [module.eks]
}

# ── Prometheus + Grafana ──────────────────────────────────────────────────────

resource "helm_release" "kube_prometheus" {
  name       = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "65.1.1"
  timeout    = 600

  values = [<<-EOT
    grafana:
      adminPassword: "${var.grafana_password}"
      service:
        type: NodePort
        nodePort: 32000
      sidecar:
        dashboards:
          enabled: true
      dashboardProviders:
        dashboardproviders.yaml:
          apiVersion: 1
          providers:
          - name: nvidia
            orgId: 1
            folder: NVIDIA
            type: file
            options:
              path: /var/lib/grafana/dashboards/nvidia
      dashboards:
        nvidia:
          dcgm-exporter:
            gnetId: 12239
            revision: 2
            datasource: Prometheus
    prometheus:
      prometheusSpec:
        retention: 24h
        serviceMonitorSelectorNilUsesHelmValues: false
        podMonitorSelectorNilUsesHelmValues: false
  EOT
  ]

  depends_on = [module.eks]
}

# ── HuggingFace token secret ──────────────────────────────────────────────────

resource "kubernetes_secret" "hf_token" {
  metadata {
    name      = "hf-token"
    namespace = kubernetes_namespace.vllm.metadata[0].name
  }
  data = {
    token = var.hf_token
  }
  type = "Opaque"
}
