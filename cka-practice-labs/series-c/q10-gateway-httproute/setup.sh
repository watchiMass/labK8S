#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
ensure_gateway_api
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

kubectl create namespace project-r500 --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n project-r500 apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: desktop
  labels:
    app: desktop
spec:
  replicas: 1
  selector:
    matchLabels:
      app: desktop
  template:
    metadata:
      labels:
        app: desktop
    spec:
      containers:
        - name: desktop
          image: nginx:1-alpine
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mobile
  labels:
    app: mobile
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mobile
  template:
    metadata:
      labels:
        app: mobile
    spec:
      containers:
        - name: mobile
          image: nginx:1-alpine
---
apiVersion: v1
kind: Service
metadata:
  name: desktop
spec:
  selector:
    app: desktop
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: mobile
spec:
  selector:
    app: mobile
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
  name: r500-gateway
  namespace: project-r500
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

kubectl -n project-r500 rollout status deployment/desktop --timeout=180s >/dev/null
kubectl -n project-r500 rollout status deployment/mobile --timeout=180s >/dev/null

info "Gateway API environment ready. GatewayClass: $GATEWAY_CLASS"
