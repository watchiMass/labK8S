#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-c/q07-hpa-behavior"
ensure_workdir "$QWORK"

kubectl create namespace c7-hpa --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n c7-hpa apply -f - >/dev/null <<'YAML'
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
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
YAML
kubectl -n c7-hpa rollout status deployment/web --timeout=180s >/dev/null

info "Environment ready. Namespace: c7-hpa (metrics-server is not required)"
