#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

kubectl delete namespace d02-rbac --ignore-not-found >/dev/null 2>&1 || true
kubectl delete clusterrolebinding d02-delegator-binding d02-test-crb --ignore-not-found >/dev/null 2>&1 || true
kubectl delete clusterrole d02-delegator d02-pod-reader d02-secret-reader --ignore-not-found >/dev/null 2>&1 || true

kubectl create namespace d02-rbac >/dev/null
kubectl apply -f - >/dev/null <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: d02-pod-reader
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: d02-secret-reader
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get"]
YAML

kubectl -n d02-rbac create serviceaccount delegator --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n d02-rbac create serviceaccount app-reader --dry-run=client -o yaml | kubectl apply -f - >/dev/null

info "Environment ready. Namespace: d02-rbac"
