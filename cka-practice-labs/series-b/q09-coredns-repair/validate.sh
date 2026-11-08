#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
info "Validating CoreDNS configuration and live DNS resolution..."

DNS_DEPLOY=$(kubectl -n kube-system get deployment -l k8s-app=kube-dns \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -z "$DNS_DEPLOY" ]]; then
  fail "CoreDNS Deployment not found"
  summary
fi
pass "CoreDNS Deployment $DNS_DEPLOY found"

DNS_CM=$(kubectl -n kube-system get deployment "$DNS_DEPLOY" \
  -o jsonpath='{.spec.template.spec.volumes[?(@.configMap)].configMap.name}' 2>/dev/null | awk '{print $1}')
[[ -n "$DNS_CM" ]] || DNS_CM="$DNS_DEPLOY"

corefile=$(kubectl -n kube-system get configmap "$DNS_CM" -o jsonpath='{.data.Corefile}' 2>/dev/null || true)
if grep -q '\.:53' <<<"$corefile"; then
  pass "Corefile listens on port 53"
else
  fail "Corefile does not listen on port 53"
fi
if grep -q '\.:5353' <<<"$corefile"; then
  fail "Corefile still listens on the wrong port 5353"
else
  pass "Corefile no longer uses port 5353"
fi

if kubectl -n kube-system rollout status deployment/"$DNS_DEPLOY" --timeout=10s >/dev/null 2>&1; then
  pass "CoreDNS Deployment is fully rolled out"
else
  fail "CoreDNS Deployment is not fully rolled out"
fi

kubectl delete pod dns-probe -n default --ignore-not-found >/dev/null 2>&1 || true
kubectl run dns-probe -n default --image=busybox:1.36 --restart=Never -- sleep 600 >/dev/null 2>&1 || true
kubectl wait --for=condition=Ready pod/dns-probe -n default --timeout=120s >/dev/null 2>&1 || true

resolved=""
for _ in $(seq 1 60); do
  resolved=$(kubectl -n default exec dns-probe -- nslookup kubernetes.default 2>/dev/null || true)
  if grep -qi 'Name:' <<<"$resolved"; then
    break
  fi
  sleep 2
done
if grep -qi 'Name:' <<<"$resolved"; then
  pass "dns-probe resolves kubernetes.default"
else
  fail "dns-probe cannot resolve kubernetes.default"
fi

kubectl delete pod dns-probe -n default --ignore-not-found >/dev/null 2>&1 || true
summary
