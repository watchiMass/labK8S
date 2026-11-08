#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=b11-endpoints
info "Validating Service selector, port and live traffic..."

label=$(kubectl -n "$NS" get deployment backend \
  -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null || true)
check_eq "Deployment backend Pods keep label app=backend" "$label" "backend"

stype=$(kubectl -n "$NS" get service backend -o jsonpath='{.spec.type}' 2>/dev/null || true)
check_eq "Service backend is ClusterIP" "$stype" "ClusterIP"

selector=$(kubectl -n "$NS" get service backend \
  -o jsonpath='{.spec.selector.app}' 2>/dev/null || true)
check_eq "Service selector matches app=backend" "$selector" "backend"

target=$(kubectl -n "$NS" get service backend \
  -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null || true)
check_eq "Service targetPort is 80" "$target" "80"

pod_ip=$(kubectl -n "$NS" get pods -l app=backend -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || true)
for _ in $(seq 1 15); do
  ep_ip=$(kubectl -n "$NS" get endpoints backend -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || true)
  [[ -n "$ep_ip" ]] && break
  sleep 2
done
if [[ -n "${ep_ip:-}" && "$ep_ip" == "$pod_ip" ]]; then
  pass "Service backend has the backend Pod as an Endpoint"
else
  fail "Service backend Endpoint '$ep_ip' does not match Pod IP '$pod_ip'"
fi

if timeout 15 kubectl -n "$NS" exec client -- wget -q -T 5 -O - http://backend 2>/dev/null | grep -qi nginx; then
  pass "client can reach http://backend"
else
  fail "client cannot reach http://backend"
fi

summary
