#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

kubectl delete namespace d06-quota --ignore-not-found >/dev/null 2>&1 || true
kubectl create namespace d06-quota >/dev/null
kubectl apply -f - >/dev/null <<'YAML'
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: d06-high
value: 100000
preemptionPolicy: PreemptLowerPriority
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: d06-low
value: 1000
preemptionPolicy: Never
YAML

info "Environment ready. Namespace: d06-quota; PriorityClasses d06-high/d06-low exist."
