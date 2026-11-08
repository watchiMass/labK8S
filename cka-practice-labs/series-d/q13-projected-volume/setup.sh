#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

kubectl create namespace d13-projected --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n d13-projected delete pod projected-app --ignore-not-found >/dev/null 2>&1 || true
kubectl -n d13-projected apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  app.properties: |
    mode=prod
    timeout=5
  feature.flag: enabled
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
stringData:
  password: secret-projected
YAML

info "Environment ready. Namespace: d13-projected"
