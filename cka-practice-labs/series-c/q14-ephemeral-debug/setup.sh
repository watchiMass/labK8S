#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

kubectl create namespace c14-debug --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n c14-debug apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: target
  labels:
    app: target
spec:
  containers:
    - name: app
      image: registry.k8s.io/pause:3.10
YAML
kubectl -n c14-debug wait --for=condition=Ready pod/target --timeout=120s >/dev/null

uid=$(kubectl -n c14-debug get pod target -o jsonpath='{.metadata.uid}')
printf '%s\n' "$uid" >"$QWORK/pod-uid.txt"

info "Environment ready. Pod target UID: $uid"
