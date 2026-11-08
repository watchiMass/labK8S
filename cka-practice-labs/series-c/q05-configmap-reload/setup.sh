#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

kubectl create namespace c5-config --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n c5-config delete configmap locked-config --ignore-not-found >/dev/null 2>&1 || true

kubectl -n c5-config apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  theme: light
  version: "1"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-app
  labels:
    app: config-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: config-app
  template:
    metadata:
      labels:
        app: config-app
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["sleep", "3600"]
          volumeMounts:
            - name: config
              mountPath: /etc/app-config
              readOnly: true
      volumes:
        - name: config
          configMap:
            name: app-config
YAML

kubectl -n c5-config rollout status deployment/config-app --timeout=180s >/dev/null
info "Environment ready. Namespace: c5-config"
