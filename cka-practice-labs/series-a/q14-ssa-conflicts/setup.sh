#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

kubectl create namespace a14-ssa --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n a14-ssa delete deployment web --ignore-not-found >/dev/null 2>&1 || true

cat > "$QWORK/base.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: a14-ssa
  labels:
    app: web
    owner: platform
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
          ports:
            - containerPort: 80
YAML

cat > "$QWORK/update.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: a14-ssa
  annotations:
    change-cause: scale-up
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: web
          image: nginx:1.27-alpine
YAML

kubectl apply --server-side --field-manager=platform-team --force-conflicts -f "$QWORK/base.yaml" >/dev/null
kubectl -n a14-ssa rollout status deployment/web --timeout=180s >/dev/null

info "Environment ready. Files: $QWORK/base.yaml and $QWORK/update.yaml"
