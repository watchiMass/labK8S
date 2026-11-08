#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=c7-hpa
info "Validating HPA targets, metrics and behaviour..."

if kubectl -n "$NS" get hpa web-hpa >/dev/null 2>&1; then
  pass "HPA web-hpa exists"
else
  fail "HPA web-hpa is missing"
  summary
fi

target=$(kubectl -n "$NS" get hpa web-hpa \
  -o jsonpath='{.spec.scaleTargetRef.kind}/{.spec.scaleTargetRef.name}' 2>/dev/null || true)
check_eq "HPA targets Deployment/web" "$target" "Deployment/web"

min=$(kubectl -n "$NS" get hpa web-hpa -o jsonpath='{.spec.minReplicas}' 2>/dev/null || true)
max=$(kubectl -n "$NS" get hpa web-hpa -o jsonpath='{.spec.maxReplicas}' 2>/dev/null || true)
check_eq "minReplicas is 2" "$min" "2"
check_eq "maxReplicas is 8" "$max" "8"

metric=$(kubectl -n "$NS" get hpa web-hpa \
  -o jsonpath='{.spec.metrics[0].resource.name}/{.spec.metrics[0].resource.target.type}/{.spec.metrics[0].resource.target.averageUtilization}' 2>/dev/null || true)
check_eq "CPU utilisation target is 60%" "$metric" "cpu/Utilization/60"

up_stab=$(kubectl -n "$NS" get hpa web-hpa \
  -o jsonpath='{.spec.behavior.scaleUp.stabilizationWindowSeconds}' 2>/dev/null || true)
check_eq "scaleUp stabilization window is 0" "$up_stab" "0"

up_policy=$(kubectl -n "$NS" get hpa web-hpa \
  -o jsonpath='{.spec.behavior.scaleUp.policies[0].type}/{.spec.behavior.scaleUp.policies[0].value}/{.spec.behavior.scaleUp.policies[0].periodSeconds}' 2>/dev/null || true)
check_eq "scaleUp policy is Pods 2/60s" "$up_policy" "Pods/2/60"

down_stab=$(kubectl -n "$NS" get hpa web-hpa \
  -o jsonpath='{.spec.behavior.scaleDown.stabilizationWindowSeconds}' 2>/dev/null || true)
check_eq "scaleDown stabilization window is 300" "$down_stab" "300"

down_policy=$(kubectl -n "$NS" get hpa web-hpa \
  -o jsonpath='{.spec.behavior.scaleDown.policies[0].type}/{.spec.behavior.scaleDown.policies[0].value}/{.spec.behavior.scaleDown.policies[0].periodSeconds}' 2>/dev/null || true)
check_eq "scaleDown policy is Percent 50/60s" "$down_policy" "Percent/50/60"

cpu_req=$(kubectl -n "$NS" get deployment web \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || true)
check_eq "Deployment still has a CPU request (100m)" "$cpu_req" "100m"

summary
