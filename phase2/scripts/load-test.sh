#!/bin/bash
# Hammers vLLM with 30 concurrent requests to drive DCGM_FI_DEV_GPU_UTIL > 80%
# Watch in Grafana: dashboard "NVIDIA DCGM Exporter Dashboard" → GPU Utilization

set -euo pipefail

NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
NODE_PORT=$(kubectl get svc vllm -n vllm -o jsonpath='{.spec.ports[0].nodePort}')
ENDPOINT="http://${NODE_IP}:${NODE_PORT}/v1/completions"
CONCURRENCY=${1:-30}
MODEL="meta-llama/Llama-3.1-8B-Instruct"

echo "Endpoint : $ENDPOINT"
echo "Concurrency: $CONCURRENCY parallel requests"
echo "Watch GPU : kubectl top nodes (or Grafana :32000)"
echo ""

PROMPT="Explain the mathematics behind transformer attention mechanisms in detail, including the scaled dot-product attention formula and why scaling is necessary."

send_request() {
  curl -s -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"${MODEL}\",
      \"prompt\": \"${PROMPT}\",
      \"max_tokens\": 300,
      \"temperature\": 0.7
    }" > /dev/null
}

echo "Firing ${CONCURRENCY} concurrent requests..."
for i in $(seq 1 "$CONCURRENCY"); do
  send_request &
done
wait

echo ""
echo "Done. Open Grafana at http://<node-ip>:32000 — look for DCGM_FI_DEV_GPU_UTIL spike."
