#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

WORKER=$(first_worker)
[[ -n "$WORKER" ]] || die "No worker node found."
printf '%s\n' "$WORKER" >"$QWORK/node.txt"

existing=$(kubectl get node "$WORKER" \
  -o jsonpath='{range .spec.taints[?(@.key=="dedicated")]}{.value}{"\n"}{end}' 2>/dev/null || true)
if [[ -z "$existing" ]]; then
  kubectl taint node "$WORKER" dedicated=cka:NoSchedule --overwrite >/dev/null
  printf 'added\n' >"$QWORK/taint-added"
else
  info "Node $WORKER already has a dedicated taint; leaving it untouched."
fi

kubectl create namespace b12-pending --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n b12-pending apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-worker
  labels:
    app: gpu-worker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gpu-worker
  template:
    metadata:
      labels:
        app: gpu-worker
    spec:
      nodeSelector:
        dedicated: cka
      containers:
        - name: gpu-worker
          image: busybox:1.36
          command: ["sleep", "3600"]
YAML

sleep 5
info "Environment ready. Target worker: $WORKER (node.txt)"
