#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-c/q01-dns-fqdn"
ensure_workdir "$QWORK"

kubectl create namespace lima-control --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create namespace lima-workload --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl -n lima-control apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: dns-config
data:
  DNS_1: unset
  DNS_2: unset
  DNS_3: unset
  DNS_4: unset
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: controller
  labels:
    app: controller
spec:
  replicas: 1
  selector:
    matchLabels:
      app: controller
  template:
    metadata:
      labels:
        app: controller
    spec:
      containers:
        - name: controller
          image: busybox:1.36
          command: ["sleep", "3600"]
          envFrom:
            - configMapRef:
                name: dns-config
YAML

kubectl -n lima-workload apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: department
  labels:
    app: department
spec:
  replicas: 1
  selector:
    matchLabels:
      app: department
  template:
    metadata:
      labels:
        app: department
        team: lima
    spec:
      containers:
        - name: department
          image: nginx:1-alpine
---
apiVersion: v1
kind: Service
metadata:
  name: department
spec:
  clusterIP: None
  selector:
    team: lima
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: section100
  labels:
    app: section100
    team: lima
spec:
  containers:
    - name: section100
      image: nginx:1-alpine
YAML

kubectl -n lima-control rollout status deployment/controller --timeout=180s >/dev/null
kubectl -n lima-workload rollout status deployment/department --timeout=180s >/dev/null
kubectl -n lima-workload wait --for=condition=Ready pod/section100 --timeout=120s >/dev/null

info "Environment ready. Work directory: $QWORK"
