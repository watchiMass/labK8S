#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-a/q15-pdb"
ensure_workdir "$QWORK"

kubectl create namespace a15-pdb --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n a15-pdb apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels:
    app: api
spec:
  replicas: 4
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
kubectl -n a15-pdb rollout status deployment/api --timeout=180s >/dev/null

info "Environment ready. Work directory: $QWORK"
