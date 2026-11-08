#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

kubectl create namespace a6-front --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create namespace a6-back --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl -n a6-front apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: front
spec:
  replicas: 1
  selector:
    matchLabels:
      app: front
  template:
    metadata:
      labels:
        app: front
    spec:
      containers:
        - name: front
          image: busybox:1.36
          command: ["sleep", "3600"]
YAML

kubectl -n a6-back apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 1
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
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
        - name: db
          image: nginx:1-alpine
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tester
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tester
  template:
    metadata:
      labels:
        app: tester
    spec:
      containers:
        - name: tester
          image: busybox:1.36
          command: ["sleep", "3600"]
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
---
apiVersion: v1
kind: Service
metadata:
  name: db
spec:
  selector:
    app: db
  ports:
    - port: 80
      targetPort: 80
YAML

for d in front; do
  kubectl -n a6-front rollout status "deployment/$d" --timeout=180s >/dev/null
done
for d in api db tester; do
  kubectl -n a6-back rollout status "deployment/$d" --timeout=180s >/dev/null
done

info "Environment ready. Work directory: $QWORK"
