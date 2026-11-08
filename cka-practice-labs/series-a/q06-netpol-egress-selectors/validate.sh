#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
info "Validating cross-namespace policies and traffic..."

if kubectl -n a6-back get networkpolicy api-ingress >/dev/null 2>&1; then
  pass "NetworkPolicy api-ingress exists"
else
  fail "NetworkPolicy api-ingress is missing"
fi
if kubectl -n a6-front get networkpolicy front-egress >/dev/null 2>&1; then
  pass "NetworkPolicy front-egress exists"
else
  fail "NetworkPolicy front-egress is missing"
fi

ing_ns=$(kubectl -n a6-back get networkpolicy api-ingress \
  -o jsonpath='{.spec.ingress[0].from[0].namespaceSelector.matchLabels.kubernetes\.io/metadata\.name}' 2>/dev/null || true)
check_eq "api ingress selects namespace a6-front" "$ing_ns" "a6-front"

ing_pod=$(kubectl -n a6-back get networkpolicy api-ingress \
  -o jsonpath='{.spec.ingress[0].from[0].podSelector.matchLabels.app}' 2>/dev/null || true)
check_eq "api ingress selects app=front" "$ing_pod" "front"

eg_ns=$(kubectl -n a6-front get networkpolicy front-egress \
  -o jsonpath='{range .spec.egress[*].to[*].namespaceSelector.matchLabels}{.}{"\n"}{end}' 2>/dev/null || true)
check_contains "front egress targets namespace a6-back" "$eg_ns" "a6-back"

eg_pod=$(kubectl -n a6-front get networkpolicy front-egress \
  -o jsonpath='{range .spec.egress[*].to[*].podSelector.matchLabels}{.}{"\n"}{end}' 2>/dev/null || true)
check_contains "front egress targets app=api" "$eg_pod" "api"

http_ok() { # ns deploy url
  local ns="$1" dep="$2" url="$3"
  timeout 12 kubectl -n "$ns" exec "deploy/$dep" -- wget -q -T 5 -O - "$url" 2>/dev/null | grep -qi nginx
}

if http_ok a6-front front http://api.a6-back.svc.cluster.local; then
  pass "front can reach api"
else
  fail "front cannot reach api"
fi

if http_ok a6-front front http://db.a6-back.svc.cluster.local; then
  fail "front can reach db despite the egress policy"
else
  pass "front is blocked from reaching db"
fi

if http_ok a6-back tester http://api.a6-back.svc.cluster.local; then
  fail "tester can reach api despite the ingress policy"
else
  pass "tester is blocked from reaching api"
fi

if http_ok a6-back tester http://db.a6-back.svc.cluster.local; then
  pass "tester can still reach db"
else
  fail "tester cannot reach db (policy applies too broadly)"
fi

if timeout 12 kubectl -n a6-front exec deploy/front -- nslookup kubernetes.default 2>/dev/null | grep -qi 'Name:'; then
  pass "front can resolve DNS"
else
  fail "front cannot resolve DNS (missing DNS egress rule)"
fi

summary
