#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

kubectl create namespace d16-token --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n d16-token delete pod token-target --ignore-not-found >/dev/null 2>&1 || true
kubectl -n d16-token apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bound-reader
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: bound-reader
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: bound-reader-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: bound-reader
subjects:
  - kind: ServiceAccount
    name: bound-reader
    namespace: d16-token
YAML

rm -f "$QWORK/token.txt" "$QWORK/before.txt" "$QWORK/after.txt"
info "Environment ready. Namespace: d16-token"
