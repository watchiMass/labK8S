#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
ensure_gateway_api
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

kubectl create namespace d09-gw --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n d09-gw apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stable
  labels:
    app: stable
spec:
  replicas: 1
  selector:
    matchLabels:
      app: stable
  template:
    metadata:
      labels:
        app: stable
    spec:
      containers:
        - name: stable
          image: nginx:1-alpine
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: canary
  labels:
    app: canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: canary
  template:
    metadata:
      labels:
        app: canary
    spec:
      containers:
        - name: canary
          image: nginx:1-alpine
---
apiVersion: v1
kind: Service
metadata:
  name: stable
spec:
  selector:
    app: stable
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: canary
spec:
  selector:
    app: canary
  ports:
    - port: 80
      targetPort: 80
YAML

GATEWAY_CLASS=$(kubectl get gatewayclass -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
[[ -n "$GATEWAY_CLASS" ]] || GATEWAY_CLASS="cka-lab"

cat > "$QWORK/gateway.yaml" <<YAML
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: d09-gateway
  namespace: d09-gw
spec:
  gatewayClassName: ${GATEWAY_CLASS}
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same
YAML
kubectl apply -f "$QWORK/gateway.yaml" >/dev/null

kubectl -n d09-gw rollout status deployment/stable --timeout=180s >/dev/null
kubectl -n d09-gw rollout status deployment/canary --timeout=180s >/dev/null

info "Gateway API environment ready. Gateway: d09-gw/d09-gateway"
