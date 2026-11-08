#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-a/q05-netpol-deny-dns"
ensure_workdir "$QWORK"

kubectl create namespace a5-netpol --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n a5-netpol apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
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
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
  template:
    metadata:
      labels:
        app: client
    spec:
      containers:
        - name: client
          image: busybox:1.36
          command: ["sleep", "3600"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blocked
spec:
  replicas: 1
  selector:
    matchLabels:
      app: blocked
  template:
    metadata:
      labels:
        app: blocked
    spec:
      containers:
        - name: blocked
          image: busybox:1.36
          command: ["sleep", "3600"]
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
kubectl -n a5-netpol rollout status deployment/web --timeout=180s >/dev/null
kubectl -n a5-netpol rollout status deployment/client --timeout=180s >/dev/null
kubectl -n a5-netpol rollout status deployment/blocked --timeout=180s >/dev/null

info "Environment ready. Work directory: $QWORK"
