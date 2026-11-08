#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-a/q10-kustomize-hpa"
ensure_workdir "$QWORK"

rm -rf "$QWORK/base" "$QWORK/overlays"
mkdir -p "$QWORK/base" "$QWORK/overlays/staging" "$QWORK/overlays/prod"

cat > "$QWORK/base/deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  labels:
    app: api-gateway
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
        - name: api-gateway
          image: nginx:1-alpine
          ports:
            - containerPort: 80
YAML

cat > "$QWORK/base/configmap.yaml" <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: horizontal-scaling-config
data:
  mode: external-autoscaler
YAML

cat > "$QWORK/base/service.yaml" <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
spec:
  selector:
    app: api-gateway
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

cat > "$QWORK/overlays/staging/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: a10-staging
resources:
  - ../../base
YAML

cat > "$QWORK/overlays/prod/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: a10-prod
resources:
  - ../../base
YAML

kubectl create namespace a10-staging --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create namespace a10-prod --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl apply -k "$QWORK/overlays/staging" >/dev/null
kubectl apply -k "$QWORK/overlays/prod" >/dev/null
kubectl -n a10-staging rollout status deployment/api-gateway --timeout=180s >/dev/null
kubectl -n a10-prod rollout status deployment/api-gateway --timeout=180s >/dev/null

info "Environment ready. Kustomize root: $QWORK"
