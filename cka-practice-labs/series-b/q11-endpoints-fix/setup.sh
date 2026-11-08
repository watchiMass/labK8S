#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-b/q11-endpoints-fix"
ensure_workdir "$QWORK"

kubectl create namespace b11-endpoints --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n b11-endpoints apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: nginx:1-alpine
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend-v1
  ports:
    - port: 80
      targetPort: 8080
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  labels:
    app: client
spec:
  containers:
    - name: client
      image: busybox:1.36
      command: ["sleep", "3600"]
YAML

kubectl -n b11-endpoints rollout status deployment/backend --timeout=180s >/dev/null
kubectl -n b11-endpoints wait --for=condition=Ready pod/client --timeout=120s >/dev/null

info "Environment ready. Namespace: b11-endpoints"
