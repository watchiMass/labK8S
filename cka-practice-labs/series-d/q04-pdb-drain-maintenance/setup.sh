#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

WORKER_COUNT=$(worker_nodes | grep -c . || true)
if [[ "$WORKER_COUNT" -lt 2 ]]; then
  die "This question needs at least 2 worker nodes (found $WORKER_COUNT)."
fi

WORKER=$(first_worker)
printf '%s\n' "$WORKER" >"$QWORK/node.txt"

kubectl create namespace d04-maint --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n d04-maint apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels:
    app: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: web
      containers:
        - name: web
          image: nginx:1-alpine
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: web
YAML

kubectl -n d04-maint rollout status deployment/web --timeout=180s >/dev/null
for _ in $(seq 1 30); do
  healthy=$(kubectl -n d04-maint get pdb web-pdb -o jsonpath='{.status.currentHealthy}' 2>/dev/null || true)
  [[ "$healthy" == "3" ]] && break
  sleep 2
done

info "Environment ready. Worker to maintain: $WORKER (PDB minAvailable=3)."
