#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
info "Validating renders and the live prod overlay..."

base_render=$(kubectl kustomize "$QWORK/base" 2>/dev/null || true)
staging_render=$(kubectl kustomize "$QWORK/overlays/staging" 2>/dev/null || true)
prod_render=$(kubectl kustomize "$QWORK/overlays/prod" 2>/dev/null || true)

if grep -q 'image: nginx:1-alpine' <<<"$base_render" && ! grep -q '1.27-alpine' <<<"$base_render"; then
  pass "base image is still nginx:1-alpine"
else
  fail "base image was changed"
fi

if grep -q 'replicas: 1' <<<"$base_render" && grep -q 'replicas: 1' <<<"$staging_render"; then
  pass "base/staging replicas remain 1"
else
  fail "base or staging replicas were changed"
fi

if grep -q 'LOG_LEVEL' <<<"$staging_render"; then
  fail "staging overlay contains the prod-only LOG_LEVEL variable"
else
  pass "staging does not contain LOG_LEVEL"
fi

if grep -q 'image: nginx:1.27-alpine' <<<"$prod_render"; then
  pass "prod renders nginx:1.27-alpine"
else
  fail "prod does not render nginx:1.27-alpine"
fi

if grep -q 'replicas: 3' <<<"$prod_render"; then
  pass "prod renders 3 replicas"
else
  fail "prod does not render 3 replicas"
fi

if grep -q 'name: LOG_LEVEL' <<<"$prod_render" && grep -q 'value: debug' <<<"$prod_render"; then
  pass "prod renders LOG_LEVEL=debug"
else
  fail "prod does not render LOG_LEVEL=debug"
fi

if grep -q 'tier: frontend' <<<"$prod_render"; then
  pass "prod renders the tier=frontend label"
else
  fail "prod does not render the tier=frontend label"
fi

if kubectl -n a11-prod rollout status deployment/web --timeout=10s >/dev/null 2>&1; then
  pass "Deployment web is fully rolled out in a11-prod"
else
  fail "Deployment web is not fully rolled out in a11-prod"
fi

image=$(kubectl -n a11-prod get deployment web \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
check_eq "live image is nginx:1.27-alpine" "$image" "nginx:1.27-alpine"

replicas=$(kubectl -n a11-prod get deployment web -o jsonpath='{.spec.replicas}' 2>/dev/null || true)
check_eq "live replicas is 3" "$replicas" "3"

env_value() {
  kubectl -n a11-prod get deployment web \
    -o jsonpath="{.spec.template.spec.containers[0].env[?(@.name==\"$1\")].value}" 2>/dev/null || true
}
check_eq "live LOG_LEVEL is debug" "$(env_value LOG_LEVEL)" "debug"
check_eq "live CONFIG_MODE is still dev" "$(env_value CONFIG_MODE)" "dev"

label=$(kubectl -n a11-prod get deployment web -o jsonpath='{.metadata.labels.tier}' 2>/dev/null || true)
check_eq "Deployment has metadata label tier=frontend" "$label" "frontend"

selector=$(kubectl -n a11-prod get deployment web \
  -o jsonpath='{.spec.selector.matchLabels.tier}' 2>/dev/null || true)
check_eq "Deployment selector includes tier=frontend" "$selector" "frontend"

template=$(kubectl -n a11-prod get deployment web \
  -o jsonpath='{.spec.template.metadata.labels.tier}' 2>/dev/null || true)
check_eq "Pod template includes tier=frontend" "$template" "frontend"

svc_label=$(kubectl -n a11-prod get service web -o jsonpath='{.metadata.labels.tier}' 2>/dev/null || true)
check_eq "Service has metadata label tier=frontend" "$svc_label" "frontend"

endpoints=$(kubectl -n a11-prod get endpoints web \
  -o jsonpath='{range .subsets[*].addresses[*]}{.ip}{"\n"}{end}' 2>/dev/null || true)
if [[ -n "$endpoints" ]]; then
  pass "prod Service web has Endpoints"
else
  fail "prod Service web has no Endpoints (selector/template labels do not match)"
fi

summary
