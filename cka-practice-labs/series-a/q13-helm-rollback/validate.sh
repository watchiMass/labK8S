#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_cmd helm "Install Helm 3 and re-run validation."
QWORK="$SCRIPT_DIR"
info "Validating Helm release state..."

for f in Chart.yaml values.yaml templates/deployment.yaml templates/service.yaml; do
  if [[ -s "$QWORK/webchart/$f" ]]; then
    pass "chart file $f exists"
  else
    fail "missing chart file $f"
  fi
done

status=$(helm -n a13-helm status web -o json 2>/dev/null | grep -o '"status":"[^"]*"' | head -n1 | cut -d'"' -f4 || true)
if [[ -z "$status" ]]; then
  status=$(helm -n a13-helm list -a -o json 2>/dev/null | grep -o '"status":"[^"]*"' | head -n1 | cut -d'"' -f4 || true)
fi
check_eq "Helm release web is deployed" "$status" "deployed"

history_count=$(helm -n a13-helm history web -o json 2>/dev/null | grep -o '"revision":' | wc -l | tr -d ' ')
if [[ "${history_count:-0}" -ge 3 ]]; then
  pass "release history has at least 3 revisions"
else
  fail "release history has ${history_count:-0} revision(s), expected at least 3"
fi

if kubectl -n a13-helm rollout status deployment/web --timeout=10s >/dev/null 2>&1; then
  pass "Deployment web is fully rolled out"
else
  fail "Deployment web is not fully rolled out"
fi

replicas=$(kubectl -n a13-helm get deployment web -o jsonpath='{.spec.replicas}' 2>/dev/null || true)
check_eq "Deployment replicas is 2 after rollback" "$replicas" "2"

image=$(kubectl -n a13-helm get deployment web \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
check_eq "Deployment image is nginx:1-alpine after rollback" "$image" "nginx:1-alpine"

ready=$(kubectl -n a13-helm get pods -l app.kubernetes.io/instance=web \
  -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
if [[ -z "$ready" ]]; then
  ready=$(kubectl -n a13-helm get pods -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
fi
true_count=$(grep -o 'True' <<<"$ready" | wc -l | tr -d ' ')
check_eq "two release Pods are Ready" "$true_count" "2"

svc=$(kubectl -n a13-helm get service web -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || true)
check_eq "Service web exposes port 80" "$svc" "80"

summary
