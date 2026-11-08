#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
info "Validating selector-less Service, Endpoints and traffic..."

stype=$(kubectl -n c2-app get service external-api -o jsonpath='{.spec.type}' 2>/dev/null || true)
check_eq "Service external-api exists and is ClusterIP" "$stype" "ClusterIP"

selector=$(kubectl -n c2-app get service external-api -o jsonpath='{.spec.selector}' 2>/dev/null || true)
if [[ -z "$selector" || "$selector" == "{}" ]]; then
  pass "Service external-api has no selector"
else
  fail "Service external-api has a selector ($selector)"
fi

port=$(kubectl -n c2-app get service external-api -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || true)
check_eq "Service exposes port 80" "$port" "80"

ext_ip=$(kubectl -n c2-ext get pods -l app=mock-external -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || true)
if [[ -z "$ext_ip" ]]; then
  fail "could not determine the mock-external Pod IP"
else
  pass "mock-external Pod IP is $ext_ip"
fi

ep_ip=$(kubectl -n c2-app get endpoints external-api \
  -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || true)
ep_port=$(kubectl -n c2-app get endpoints external-api \
  -o jsonpath='{.subsets[0].ports[0].port}' 2>/dev/null || true)

if [[ -n "$ep_ip" ]]; then
  check_eq "Endpoints points at the mock-external Pod IP" "$ep_ip" "$ext_ip"
  check_eq "Endpoints port is 80" "$ep_port" "80"
else
  slice_ip=$(kubectl -n c2-app get endpointslices \
    -l kubernetes.io/service-name=external-api \
    -o jsonpath='{.items[0].endpoints[0].addresses[0]}' 2>/dev/null || true)
  slice_port=$(kubectl -n c2-app get endpointslices \
    -l kubernetes.io/service-name=external-api \
    -o jsonpath='{.items[0].ports[0].port}' 2>/dev/null || true)
  if [[ -n "$slice_ip" ]]; then
    check_eq "EndpointSlice points at the mock-external Pod IP" "$slice_ip" "$ext_ip"
    check_eq "EndpointSlice port is 80" "$slice_port" "80"
  else
    fail "no Endpoints or EndpointSlice found for external-api"
  fi
fi

for _ in $(seq 1 15); do
  body=$(timeout 15 kubectl -n c2-app exec client -- \
    wget -q -T 5 -O - http://external-api.c2-app.svc.cluster.local 2>/dev/null || true)
  grep -qi nginx <<<"$body" && break
  sleep 2
done
if grep -qi nginx <<<"$body"; then
  pass "client reaches the external endpoint through the Service"
else
  fail "client cannot reach http://external-api"
fi

summary
