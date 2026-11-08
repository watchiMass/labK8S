#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

rm -rf "$QWORK/base" "$QWORK/overlays"
mkdir -p "$QWORK/base" "$QWORK/overlays/staging" "$QWORK/overlays/prod"

cat > "$QWORK/base/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels:
    app: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: nginx:1-alpine
          ports:
            - containerPort: 80
          env:
            - name: CONFIG_MODE
              value: dev
YAML

cat > "$QWORK/base/service.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: web
  labels:
    app: web
spec:
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
YAML

cat > "$QWORK/base/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
YAML

cat > "$QWORK/overlays/staging/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: a11-staging
resources:
  - ../../base
YAML

cat > "$QWORK/overlays/prod/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: a11-prod
resources:
  - ../../base
YAML

kubectl create namespace a11-staging --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create namespace a11-prod --dry-run=client -o yaml | kubectl apply -f - >/dev/null

info "Environment ready. Kustomize root: $QWORK"
