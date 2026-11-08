#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

kubectl create namespace b10-crash --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n b10-crash apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-api
  labels:
    app: payment-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payment-api
  template:
    metadata:
      labels:
        app: payment-api
    spec:
      containers:
        - name: payment-api
          image: busybox:1.36
          env:
            - name: APP_MODE
              value: dev
          command:
            - sh
            - -c
            - |
              if [ "$APP_MODE" != "prod" ]; then
                echo "FATAL: APP_MODE must be prod" >&2
                exit 1
              fi
              echo "payment-api ready"
              sleep 3600
YAML

sleep 10
info "Deployment payment-api is expected to be crash-looping. Namespace: b10-crash"
