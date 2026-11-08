#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

kubectl create namespace c2-app --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create namespace c2-ext --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n c2-ext delete service mock-external --ignore-not-found >/dev/null 2>&1 || true

kubectl -n c2-app apply -f - >/dev/null <<'YAML'
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

kubectl -n c2-ext apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mock-external
  labels:
    app: mock-external
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mock-external
  template:
    metadata:
      labels:
        app: mock-external
    spec:
      containers:
        - name: mock-external
          image: nginx:1-alpine
YAML

kubectl -n c2-app wait --for=condition=Ready pod/client --timeout=120s >/dev/null
kubectl -n c2-ext rollout status deployment/mock-external --timeout=180s >/dev/null

info "Environment ready. Work directory: $QWORK"
