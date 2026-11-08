#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=d07-crd
info "Validating CRD schema, CEL rules and dry-run behaviour..."

if kubectl get crd servers.stable.cka.io >/dev/null 2>&1; then
  pass "CRD servers.stable.cka.io exists"
else
  fail "CRD servers.stable.cka.io is missing"
  summary
fi

check_eq "CRD group" \
  "$(kubectl get crd servers.stable.cka.io -o jsonpath='{.spec.group}' 2>/dev/null || true)" "stable.cka.io"
check_eq "CRD kind" \
  "$(kubectl get crd servers.stable.cka.io -o jsonpath='{.spec.names.kind}' 2>/dev/null || true)" "Server"
check_eq "CRD scope" \
  "$(kubectl get crd servers.stable.cka.io -o jsonpath='{.spec.scope}' 2>/dev/null || true)" "Namespaced"

rules=$(kubectl get crd servers.stable.cka.io \
  -o jsonpath='{range .spec.versions[0].schema.openAPIV3Schema.properties.spec.x-kubernetes-validations[*]}{.rule}{"\n"}{end}' 2>/dev/null || true)
rule_count=$(printf '%s\n' "$rules" | grep -c . || true)
if [[ "$rule_count" -ge 2 ]]; then
  pass "spec has at least two CEL validation rules"
else
  fail "spec has fewer than two CEL validation rules"
fi

if kubectl -n "$NS" get server web-1 >/dev/null 2>&1; then
  pass "Server web-1 exists"
else
  fail "Server web-1 is missing"
  summary
fi

check_eq "web-1 tier is prod" \
  "$(kubectl -n "$NS" get server web-1 -o jsonpath='{.spec.tier}' 2>/dev/null || true)" "prod"
check_eq "web-1 replicas is 3" \
  "$(kubectl -n "$NS" get server web-1 -o jsonpath='{.spec.replicas}' 2>/dev/null || true)" "3"

if kubectl apply --dry-run=server -f - >/dev/null 2>&1 <<'YAML'
apiVersion: stable.cka.io/v1
kind: Server
metadata:
  name: dev-one
  namespace: d07-crd
spec:
  hostname: dev.example.com
  tier: dev
  replicas: 1
YAML
then
  pass "a dev Server with 1 replica is admitted"
else
  fail "a valid dev Server with 1 replica is rejected"
fi

if kubectl apply --dry-run=server -f - >/dev/null 2>&1 <<'YAML'
apiVersion: stable.cka.io/v1
kind: Server
metadata:
  name: prod-one
  namespace: d07-crd
spec:
  hostname: prod.example.com
  tier: prod
  replicas: 1
YAML
then
  fail "a prod Server with 1 replica was admitted"
else
  pass "a prod Server with 1 replica is rejected"
fi

if kubectl -n "$NS" patch server web-1 --type merge \
  -p '{"spec":{"hostname":"other.example.com"}}' --dry-run=server >/dev/null 2>&1; then
  fail "hostname was mutable after creation"
else
  pass "hostname is immutable"
fi

if kubectl -n "$NS" patch server web-1 --type merge \
  -p '{"spec":{"replicas":2}}' --dry-run=server >/dev/null 2>&1; then
  fail "replicas were allowed to decrease"
else
  pass "decreasing replicas is rejected"
fi

if kubectl -n "$NS" patch server web-1 --type merge \
  -p '{"spec":{"replicas":4}}' --dry-run=server >/dev/null 2>&1; then
  pass "increasing replicas is allowed"
else
  fail "increasing replicas was rejected"
fi

summary
