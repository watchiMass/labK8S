#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_cmd python3 "python3 is used to patch the CoreDNS ConfigMap safely."
QWORK="$SCRIPT_DIR"
ensure_workdir "$QWORK"

kubectl create namespace d05-dns --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n d05-dns apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: nginx:1-alpine
---
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  labels:
    app: client
spec:
  containers:
    - name: client
      image: busybox:1.36
      command: ["sleep", "3600"]
YAML
kubectl -n d05-dns rollout status deployment/backend --timeout=180s >/dev/null
kubectl -n d05-dns wait --for=condition=Ready pod/client --timeout=120s >/dev/null

DNS_DEPLOY=$(kubectl -n kube-system get deployment -l k8s-app=kube-dns \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
[[ -n "$DNS_DEPLOY" ]] || die "No CoreDNS/kube-dns Deployment found in kube-system."

DNS_CM=$(kubectl -n kube-system get deployment "$DNS_DEPLOY" \
  -o jsonpath='{.spec.template.spec.volumes[?(@.configMap)].configMap.name}' 2>/dev/null | awk '{print $1}')
[[ -n "$DNS_CM" ]] || DNS_CM="$DNS_DEPLOY"
kubectl -n kube-system get configmap "$DNS_CM" >/dev/null 2>&1 \
  || die "CoreDNS ConfigMap not found (tried '$DNS_CM')."

BACKUP="$QWORK/Corefile.orig"
PATCH="$QWORK/coredns-patch.json"
printf '%s\n' "$DNS_DEPLOY" >"$QWORK/dns-deploy.txt"
printf '%s\n' "$DNS_CM" >"$QWORK/dns-cm.txt"

restore_corefile() {
  local core="$1"
  python3 -c 'import json,sys; print(json.dumps({"data":{"Corefile": sys.argv[1]}}))' "$core" >"$PATCH"
  kubectl -n kube-system patch configmap "$DNS_CM" --type merge --patch-file "$PATCH" >/dev/null
}

if [[ -s "$BACKUP" ]]; then
  core=$(cat "$BACKUP" 2>/dev/null || true)
  [[ -n "$core" ]] || die "Cannot read the saved Corefile backup $BACKUP."
  restore_corefile "$core"
  kubectl -n kube-system rollout restart deployment/"$DNS_DEPLOY" >/dev/null
  kubectl -n kube-system rollout status deployment/"$DNS_DEPLOY" --timeout=180s >/dev/null
fi

kubectl -n kube-system get configmap "$DNS_CM" -o jsonpath='{.data.Corefile}' >"$BACKUP"
rm -f "$PATCH"

info "Environment ready. CoreDNS backup saved. Namespace: d05-dns"
