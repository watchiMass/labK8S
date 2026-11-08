#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=a5-netpol
info "Validating NetworkPolicies and real Pod-to-Pod traffic..."

for p in default-deny allow-dns web-from-client client-to-web; do
  if kubectl -n "$NS" get networkpolicy "$p" >/dev/null 2>&1; then
    pass "NetworkPolicy $p exists"
  else
    fail "NetworkPolicy $p is missing"
  fi
done

types=$(kubectl -n "$NS" get networkpolicy default-deny -o jsonpath='{.spec.policyTypes[*]}' 2>/dev/null || true)
check_contains "default-deny covers ingress" "$types" "Ingress"
check_contains "default-deny covers egress" "$types" "Egress"

podsel=$(kubectl -n "$NS" get networkpolicy default-deny -o jsonpath='{.spec.podSelector}' 2>/dev/null || true)
check_eq "default-deny selects all Pods" "$podsel" "{}"

dns_ns=$(kubectl -n "$NS" get networkpolicy allow-dns \
  -o jsonpath='{.spec.egress[0].to[0].namespaceSelector.matchLabels.kubernetes\.io/metadata\.name}' 2>/dev/null || true)
check_eq "allow-dns targets namespace kube-system" "$dns_ns" "kube-system"

dns_pod=$(kubectl -n "$NS" get networkpolicy allow-dns \
  -o jsonpath='{.spec.egress[0].to[0].podSelector.matchLabels.k8s-app}' 2>/dev/null || true)
check_eq "allow-dns targets kube-dns Pods" "$dns_pod" "kube-dns"

dns_ports=$(kubectl -n "$NS" get networkpolicy allow-dns \
  -o jsonpath='{range .spec.egress[0].ports[*]}{.port}/{.protocol}{" "}{end}' 2>/dev/null || true)
check_contains "allow-dns allows TCP 53" "$dns_ports" "53/TCP"
check_contains "allow-dns allows UDP 53" "$dns_ports" "53/UDP"

ing_from=$(kubectl -n "$NS" get networkpolicy web-from-client \
  -o jsonpath='{.spec.ingress[0].from[0].podSelector.matchLabels.app}' 2>/dev/null || true)
check_eq "web ingress allows only client Pods" "$ing_from" "client"

eg_to=$(kubectl -n "$NS" get networkpolicy client-to-web \
  -o jsonpath='{.spec.egress[0].to[0].podSelector.matchLabels.app}' 2>/dev/null || true)
check_eq "client egress allows only web Pods" "$eg_to" "web"

client_ok() {
  timeout 12 kubectl -n "$NS" exec deploy/client -- \
    wget -q -T 5 -O - http://web.a5-netpol.svc.cluster.local 2>/dev/null | grep -qi nginx
}
if client_ok; then
  pass "client can reach web over HTTP"
else
  fail "client cannot reach web (check the two directional policies)"
fi

if timeout 12 kubectl -n "$NS" exec deploy/blocked -- \
     wget -q -T 4 -O - http://web.a5-netpol.svc.cluster.local >/dev/null 2>&1; then
  fail "blocked can still reach web"
else
  pass "blocked cannot reach web"
fi

dns_ok() {
  local deployment="$1"
  timeout 12 kubectl -n "$NS" exec "deploy/$deployment" -- \
    nslookup kubernetes.default 2>/dev/null | grep -qi 'Name:'
}
if dns_ok client; then
  pass "client can resolve kubernetes.default"
else
  fail "client cannot resolve DNS"
fi
if dns_ok blocked; then
  pass "blocked can resolve DNS"
else
  fail "blocked cannot resolve DNS"
fi

summary
