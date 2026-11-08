#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-d/q05-coredns-rewrite"
info "Validating CoreDNS rewrite and DNS resolution..."

DNS_DEPLOY=$(cat "$QWORK/dns-deploy.txt" 2>/dev/null || true)
DNS_CM=$(cat "$QWORK/dns-cm.txt" 2>/dev/null || true)
if [[ -z "$DNS_DEPLOY" || -z "$DNS_CM" ]]; then
  DNS_DEPLOY=$(kubectl -n kube-system get deployment -l k8s-app=kube-dns \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  DNS_CM="$DNS_DEPLOY"
fi

corefile=$(kubectl -n kube-system get configmap "$DNS_CM" -o jsonpath='{.data.Corefile}' 2>/dev/null || true)
if grep -Eq '^[[:space:]]*rewrite[[:space:]]+name' <<<"$corefile"; then
  pass "Corefile contains a rewrite name rule"
else
  fail "Corefile does not contain a 'rewrite name' rule"
fi

backend_ip=$(kubectl -n d05-dns get service backend -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)
if [[ -n "$backend_ip" ]]; then
  pass "backend Service ClusterIP is $backend_ip"
else
  fail "backend Service has no ClusterIP"
fi

if kubectl -n kube-system rollout status deployment/"$DNS_DEPLOY" --timeout=10s >/dev/null 2>&1; then
  pass "CoreDNS Deployment is fully rolled out"
else
  warn "CoreDNS Deployment is not fully rolled out yet; resolution may take longer."
fi

alias_out=""
for _ in $(seq 1 90); do
  alias_out=$(kubectl -n d05-dns exec client -- nslookup api.internal. 2>/dev/null || true)
  [[ -n "$backend_ip" ]] && grep -Fq "$backend_ip" <<<"$alias_out" && break
  sleep 2
done
if [[ -n "$backend_ip" ]] && grep -Fq "$backend_ip" <<<"$alias_out"; then
  pass "api.internal. resolves to the backend ClusterIP"
else
  fail "api.internal. does not resolve to $backend_ip"
fi

base_out=$(kubectl -n d05-dns exec client -- nslookup kubernetes.default 2>/dev/null || true)
if grep -qi 'Name:' <<<"$base_out"; then
  pass "kubernetes.default still resolves"
else
  fail "normal cluster DNS resolution is broken"
fi

summary
