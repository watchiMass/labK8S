#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

kubectl delete csr dev-anna --ignore-not-found >/dev/null 2>&1 || true
kubectl create namespace a1-dev --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n a1-dev apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels:
    app: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: nginx:1-alpine
YAML
kubectl -n a1-dev rollout status deployment/web --timeout=180s >/dev/null

rm -f "$QWORK/dev-anna.key" "$QWORK/dev-anna.csr" "$QWORK/dev-anna.crt" \
      "$QWORK/dev-anna.kubeconfig" "$QWORK/ca.crt"
info "Environment ready. Work directory: $QWORK"
