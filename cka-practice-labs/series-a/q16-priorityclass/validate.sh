#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=a16-priority
info "Validating PriorityClasses and effective Pod priority..."

high=$(kubectl get priorityclass high-priority -o jsonpath='{.value}' 2>/dev/null || true)
check_eq "high-priority value is 100000" "$high" "100000"

high_policy=$(kubectl get priorityclass high-priority -o jsonpath='{.preemptionPolicy}' 2>/dev/null || true)
check_eq "high-priority preemption policy" "$high_policy" "PreemptLowerPriority"

low=$(kubectl get priorityclass low-priority -o jsonpath='{.value}' 2>/dev/null || true)
check_eq "low-priority value is 1000" "$low" "1000"

low_policy=$(kubectl get priorityclass low-priority -o jsonpath='{.preemptionPolicy}' 2>/dev/null || true)
check_eq "low-priority preemption policy" "$low_policy" "Never"

gd_high=$(kubectl get priorityclass high-priority -o jsonpath='{.globalDefault}' 2>/dev/null || true)
gd_low=$(kubectl get priorityclass low-priority -o jsonpath='{.globalDefault}' 2>/dev/null || true)
check_eq "high-priority is not the global default" "$gd_high" ""
check_eq "low-priority is not the global default" "$gd_low" ""

phase=$(kubectl -n "$NS" get pod low-pod -o jsonpath='{.status.phase}' 2>/dev/null || true)
check_eq "low-pod is Running" "$phase" "Running"

pc=$(kubectl -n "$NS" get pod low-pod -o jsonpath='{.spec.priorityClassName}' 2>/dev/null || true)
check_eq "low-pod uses low-priority" "$pc" "low-priority"

prio=$(kubectl -n "$NS" get pod low-pod -o jsonpath='{.spec.priority}' 2>/dev/null || true)
check_eq "low-pod effective priority is 1000" "$prio" "1000"

if kubectl -n "$NS" rollout status deployment/high-app --timeout=10s >/dev/null 2>&1; then
  pass "Deployment high-app is fully rolled out"
else
  fail "Deployment high-app is not fully rolled out"
fi

dpc=$(kubectl -n "$NS" get deployment high-app \
  -o jsonpath='{.spec.template.spec.priorityClassName}' 2>/dev/null || true)
check_eq "high-app uses high-priority" "$dpc" "high-priority"

prios=$(kubectl -n "$NS" get pods -l app=high-app -o jsonpath='{.items[*].spec.priority}' 2>/dev/null || true)
if [[ "$prios" == "100000 100000" ]]; then
  pass "both high-app Pods have effective priority 100000"
else
  fail "high-app Pod priorities are '$prios', expected two Pods at 100000"
fi

summary
