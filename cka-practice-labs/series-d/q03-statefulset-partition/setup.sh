#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-d/q03-statefulset-partition"
ensure_workdir "$QWORK"

kubectl create namespace d03-sts --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n d03-sts delete statefulset store --ignore-not-found >/dev/null 2>&1 || true
kubectl -n d03-sts delete service store-headless --ignore-not-found >/dev/null 2>&1 || true

kubectl -n d03-sts apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: store-headless
spec:
  clusterIP: None
  selector:
    app: store
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: store
  labels:
    app: store
spec:
  serviceName: store-headless
  replicas: 3
  selector:
    matchLabels:
      app: store
  template:
    metadata:
      labels:
        app: store
    spec:
      containers:
        - name: store
          image: nginx:1-alpine
          ports:
            - containerPort: 80
YAML

kubectl -n d03-sts rollout status statefulset/store --timeout=180s >/dev/null
info "Environment ready. StatefulSet store: store-0..2 on nginx:1-alpine."
