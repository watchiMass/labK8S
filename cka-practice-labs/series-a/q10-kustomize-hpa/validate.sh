#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-a/q10-kustomize-hpa"
info "Validating Kustomize render and live HPA objects..."

base_render=$(kubectl kustomize "$QWORK/base" 2>/dev/null || true)
staging_render=$(kubectl kustomize "$QWORK/overlays/staging" 2>/dev/null || true)
prod_render=$(kubectl kustomize "$QWORK/overlays/prod" 2>/dev/null || true)

if grep -q 'kind: HorizontalPodAutoscaler' <<<"$base_render"; then
  pass "base renders a HorizontalPodAutoscaler"
else
  fail "base does not render a HorizontalPodAutoscaler"
fi

if grep -q 'maxReplicas: 4' <<<"$base_render"; then
  pass "base HPA maxReplicas is 4"
else
  fail "base HPA maxReplicas is not 4"
fi

if grep -q 'horizontal-scaling-config' <<<"$base_render$staging_render$prod_render"; then
  fail "horizontal-scaling-config is still present in a Kustomize render"
else
  pass "horizontal-scaling-config is gone from all renders"
fi

if grep -q 'maxReplicas: 4' <<<"$staging_render"; then
  pass "staging HPA maxReplicas is 4"
else
  fail "staging HPA maxReplicas is not 4"
fi

if grep -q 'maxReplicas: 6' <<<"$prod_render"; then
  pass "prod HPA maxReplicas is 6"
else
  fail "prod HPA maxReplicas is not 6"
fi

for ns in a10-staging a10-prod; do
  if kubectl -n "$ns" get hpa api-gateway >/dev/null 2>&1; then
    pass "HPA api-gateway exists in $ns"
  else
    fail "HPA api-gateway is missing in $ns"
  fi
  target=$(kubectl -n "$ns" get hpa api-gateway \
    -o jsonpath='{.spec.scaleTargetRef.kind}/{.spec.scaleTargetRef.name}' 2>/dev/null || true)
  check_eq "HPA in $ns targets Deployment/api-gateway" "$target" "Deployment/api-gateway"
  min=$(kubectl -n "$ns" get hpa api-gateway -o jsonpath='{.spec.minReplicas}' 2>/dev/null || true)
  check_eq "HPA in $ns minReplicas is 2" "$min" "2"
done

max_staging=$(kubectl -n a10-staging get hpa api-gateway -o jsonpath='{.spec.maxReplicas}' 2>/dev/null || true)
check_eq "live staging HPA maxReplicas is 4" "$max_staging" "4"
max_prod=$(kubectl -n a10-prod get hpa api-gateway -o jsonpath='{.spec.maxReplicas}' 2>/dev/null || true)
check_eq "live prod HPA maxReplicas is 6" "$max_prod" "6"

for ns in a10-staging a10-prod; do
  metric=$(kubectl -n "$ns" get hpa api-gateway -o jsonpath='{.spec.metrics[0].resource.name}/{.spec.metrics[0].resource.target.type}/{.spec.metrics[0].resource.target.averageUtilization}' 2>/dev/null || true)
  check_eq "HPA in $ns uses CPU utilisation 50%" "$metric" "cpu/Utilization/50"
  if kubectl -n "$ns" get configmap horizontal-scaling-config >/dev/null 2>&1; then
    fail "ConfigMap horizontal-scaling-config still exists in $ns"
  else
    pass "ConfigMap horizontal-scaling-config is gone from $ns"
  fi
  if kubectl -n "$ns" rollout status deployment/api-gateway --timeout=10s >/dev/null 2>&1; then
    pass "Deployment api-gateway is healthy in $ns"
  else
    fail "Deployment api-gateway is not healthy in $ns"
  fi
done

summary
