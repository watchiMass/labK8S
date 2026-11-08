#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=c13-qos
info "Validating QoS classes..."

for pod in qos-guaranteed qos-burstable qos-besteffort; do
  phase=$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  check_eq "Pod $pod is Running" "$phase" "Running"
done

guaranteed=$(kubectl -n "$NS" get pod qos-guaranteed -o jsonpath='{.status.qosClass}' 2>/dev/null || true)
burstable=$(kubectl -n "$NS" get pod qos-burstable -o jsonpath='{.status.qosClass}' 2>/dev/null || true)
besteffort=$(kubectl -n "$NS" get pod qos-besteffort -o jsonpath='{.status.qosClass}' 2>/dev/null || true)
check_eq "qos-guaranteed class" "$guaranteed" "Guaranteed"
check_eq "qos-burstable class" "$burstable" "Burstable"
check_eq "qos-besteffort class" "$besteffort" "BestEffort"

greq_cpu=$(kubectl -n "$NS" get pod qos-guaranteed -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null || true)
greq_mem=$(kubectl -n "$NS" get pod qos-guaranteed -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null || true)
glim_cpu=$(kubectl -n "$NS" get pod qos-guaranteed -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null || true)
glim_mem=$(kubectl -n "$NS" get pod qos-guaranteed -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null || true)
check_eq "guaranteed request CPU" "$greq_cpu" "100m"
check_eq "guaranteed request memory" "$greq_mem" "64Mi"
check_eq "guaranteed limit CPU equals request" "$glim_cpu" "100m"
check_eq "guaranteed limit memory equals request" "$glim_mem" "64Mi"

breq_cpu=$(kubectl -n "$NS" get pod qos-burstable -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null || true)
breq_mem=$(kubectl -n "$NS" get pod qos-burstable -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null || true)
blim_cpu=$(kubectl -n "$NS" get pod qos-burstable -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null || true)
blim_mem=$(kubectl -n "$NS" get pod qos-burstable -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null || true)
check_eq "burstable request CPU" "$breq_cpu" "50m"
check_eq "burstable request memory" "$breq_mem" "32Mi"
check_eq "burstable limit CPU" "$blim_cpu" "100m"
check_eq "burstable limit memory" "$blim_mem" "64Mi"

bres=$(kubectl -n "$NS" get pod qos-besteffort -o jsonpath='{.spec.containers[0].resources}' 2>/dev/null || true)
if [[ -z "$bres" || "$bres" == "{}" || "$bres" == "map[]" ]]; then
  pass "qos-besteffort has no resource requests or limits"
else
  fail "qos-besteffort has resources set: $bres"
fi

summary
