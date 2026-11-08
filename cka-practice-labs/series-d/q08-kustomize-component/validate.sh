#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
NS=d08-kustomize
info "Validating Kustomize component, merged generator and live state..."

base_render=$(kubectl kustomize "$QWORK/base" 2>/dev/null || true)
prod_render=$(kubectl kustomize "$QWORK/overlays/prod" 2>/dev/null || true)

if [[ -s "$QWORK/components/sidecar/kustomization.yaml" ]] \
   && grep -q 'kind: Component' "$QWORK/components/sidecar/kustomization.yaml"; then
  pass "Kustomize Component components/sidecar exists"
else
  fail "components/sidecar is missing or is not a Component"
fi

if grep -q 'replicas: 1' <<<"$base_render" && grep -q 'mode: base' <<<"$base_render"; then
  pass "base render is unchanged"
else
  fail "base render was modified"
fi
if grep -q 'name: metrics' <<<"$base_render"; then
  fail "base render contains the prod-only sidecar"
else
  pass "base render has no sidecar"
fi

if grep -Eq 'name: api-config-[a-z0-9]+' <<<"$prod_render"; then
  pass "prod renders a hashed api-config ConfigMap"
else
  fail "prod does not render a hashed api-config ConfigMap"
fi
if grep -q 'mode: prod' <<<"$prod_render"; then
  pass "prod ConfigMap sets mode=prod"
else
  fail "prod ConfigMap does not set mode=prod"
fi
if grep -Eq 'timeout: "?5"?' <<<"$prod_render"; then
  pass "prod ConfigMap keeps timeout=5 through the merge"
else
  fail "prod ConfigMap lost timeout=5"
fi
if grep -Eq 'name: api-config-[a-z0-9]+' <<<"$prod_render" \
   && grep -q 'replicas: 3' <<<"$prod_render" \
   && grep -q 'name: metrics' <<<"$prod_render" \
   && grep -Eq 'instrumented: "?true"?' <<<"$prod_render"; then
  pass "prod render contains the hashed reference, 3 replicas, sidecar and label"
else
  fail "one of the prod transformations is missing from the render"
fi

if kubectl -n "$NS" rollout status deployment/api --timeout=10s >/dev/null 2>&1; then
  pass "Deployment api is fully rolled out"
else
  fail "Deployment api is not fully rolled out"
fi

replicas=$(kubectl -n "$NS" get deployment api -o jsonpath='{.spec.replicas}' 2>/dev/null || true)
check_eq "live Deployment has 3 replicas" "$replicas" "3"

label=$(kubectl -n "$NS" get deployment api -o jsonpath='{.metadata.labels.instrumented}' 2>/dev/null || true)
check_eq "live Deployment has instrumented=true" "$label" "true"

sidecar=$(kubectl -n "$NS" get deployment api \
  -o jsonpath='{.spec.template.spec.containers[?(@.name=="metrics")].image}' 2>/dev/null || true)
check_eq "live Deployment has the metrics sidecar" "$sidecar" "busybox:1.36"

cm_ref=$(kubectl -n "$NS" get deployment api \
  -o jsonpath='{.spec.template.spec.containers[0].envFrom[0].configMapRef.name}' 2>/dev/null || true)
if [[ "$cm_ref" == api-config-* ]]; then
  pass "Deployment references the hashed ConfigMap ($cm_ref)"
else
  fail "Deployment ConfigMap reference is not the hashed name (got '$cm_ref')"
fi

if [[ -n "$cm_ref" ]]; then
  mode=$(kubectl -n "$NS" get configmap "$cm_ref" -o jsonpath='{.data.mode}' 2>/dev/null || true)
  timeout=$(kubectl -n "$NS" get configmap "$cm_ref" -o jsonpath='{.data.timeout}' 2>/dev/null || true)
  check_eq "live generated ConfigMap has mode=prod" "$mode" "prod"
  check_eq "live generated ConfigMap has timeout=5" "$timeout" "5"
fi

ready=$(kubectl -n "$NS" get pods -l app=api \
  -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o 'True' | wc -l | tr -d ' ')
check_eq "3 api Pods are Ready" "$ready" "3"

endpoints=$(kubectl -n "$NS" get endpoints api \
  -o jsonpath='{range .subsets[*].addresses[*]}{.ip}{"\n"}{end}' 2>/dev/null | grep -c . || true)
check_eq "Service api has 3 Endpoints" "$endpoints" "3"

summary
