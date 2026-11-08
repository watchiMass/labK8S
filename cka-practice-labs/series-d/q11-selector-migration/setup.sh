#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-d/q11-selector-migration"
ensure_workdir "$QWORK"

kubectl create namespace d11-migrate --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n d11-migrate delete deployment api-v2 --ignore-not-found >/dev/null 2>&1 || true
kubectl -n d11-migrate apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels:
    app: api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: api
          image: nginx:1-alpine
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: api
  ports:
    - port: 80
      targetPort: 80
YAML

kubectl -n d11-migrate rollout status deployment/api --timeout=180s >/dev/null
info "Environment ready. Namespace: d11-migrate"
