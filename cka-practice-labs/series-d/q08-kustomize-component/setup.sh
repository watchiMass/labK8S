#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

rm -rf "$QWORK/base" "$QWORK/overlays" "$QWORK/components"
mkdir -p "$QWORK/base" "$QWORK/overlays/prod"

cat > "$QWORK/base/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels:
    app: api
spec:
  replicas: 1
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
          ports:
            - containerPort: 80
          envFrom:
            - configMapRef:
                name: api-config
YAML

cat > "$QWORK/base/configmap.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
data:
  mode: base
  timeout: "5"
YAML

cat > "$QWORK/base/service.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: api
  ports:
    - port: 80
      targetPort: 80
YAML

cat > "$QWORK/base/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - configmap.yaml
  - service.yaml
YAML

cat > "$QWORK/overlays/prod/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: d08-kustomize
resources:
  - ../../base
YAML

kubectl create namespace d08-kustomize --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -k "$QWORK/overlays/prod" >/dev/null
kubectl -n d08-kustomize rollout status deployment/api --timeout=180s >/dev/null

info "Environment ready. Kustomize root: $QWORK"
