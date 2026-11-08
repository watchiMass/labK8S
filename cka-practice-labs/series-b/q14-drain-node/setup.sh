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

kubectl create namespace b14-drain --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n b14-drain apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels:
    app: web
spec:
  replicas: 2
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
YAML

kubectl -n b14-drain rollout status deployment/web --timeout=180s >/dev/null
info "Environment ready. Worker to drain: $WORKER"
