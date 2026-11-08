#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-a/q04-psa-restricted"
ensure_workdir "$QWORK"

kubectl create namespace a4-psa --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n a4-psa apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: legacy
  labels:
    app: legacy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: legacy
  template:
    metadata:
      labels:
        app: legacy
    spec:
      containers:
        - name: legacy
          image: busybox:1.36
          command: ["sleep", "3600"]
YAML
kubectl -n a4-psa rollout status deployment/legacy --timeout=180s >/dev/null

info "Environment ready. Work directory: $QWORK"
