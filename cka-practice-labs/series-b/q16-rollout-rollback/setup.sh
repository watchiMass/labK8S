#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-b/q16-rollout-rollback"
ensure_workdir "$QWORK"

kubectl create namespace b16-rollout --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n b16-rollout apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels:
    app: api
spec:
  replicas: 3
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
YAML
kubectl -n b16-rollout rollout status deployment/api --timeout=180s >/dev/null

kubectl -n b16-rollout set image deployment/api api=nginx:definitely-not-a-tag >/dev/null
sleep 10

info "A bad image has been rolled out. Namespace: b16-rollout"
