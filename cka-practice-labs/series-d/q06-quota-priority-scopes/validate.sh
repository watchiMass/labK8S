#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=d06-quota
info "Validating priority-scoped quotas and workloads..."

scope_ok() { # quota expected-class
  local quota="$1" class="$2"
  local scope operator values
  scope=$(kubectl -n "$NS" get resourcequota "$quota" \
    -o jsonpath='{.spec.scopeSelector.matchExpressions[0].scopeName}' 2>/dev/null || true)
  operator=$(kubectl -n "$NS" get resourcequota "$quota" \
    -o jsonpath='{.spec.scopeSelector.matchExpressions[0].operator}' 2>/dev/null || true)
  values=$(kubectl -n "$NS" get resourcequota "$quota" \
    -o jsonpath='{.spec.scopeSelector.matchExpressions[0].values[*]}' 2>/dev/null || true)
  check_eq "$quota scope is PriorityClass" "$scope" "PriorityClass"
  check_eq "$quota scope operator is In" "$operator" "In"
  check_contains "$quota scope selects $class" "$values" "$class"
}

for q in high-quota low-quota; do
  if kubectl -n "$NS" get resourcequota "$q" >/dev/null 2>&1; then
    pass "ResourceQuota $q exists"
  else
    fail "ResourceQuota $q is missing"
  fi
done
scope_ok high-quota d06-high
scope_ok low-quota d06-low

check_eq "high-quota hard pods" \
  "$(kubectl -n "$NS" get resourcequota high-quota -o jsonpath='{.status.hard.pods}' 2>/dev/null || true)" "2"
check_eq "high-quota hard requests.cpu" \
  "$(kubectl -n "$NS" get resourcequota high-quota -o jsonpath='{.status.hard.requests\.cpu}' 2>/dev/null || true)" "500m"
check_eq "low-quota hard pods" \
  "$(kubectl -n "$NS" get resourcequota low-quota -o jsonpath='{.status.hard.pods}' 2>/dev/null || true)" "4"
check_eq "low-quota hard requests.cpu" \
  "$(kubectl -n "$NS" get resourcequota low-quota -o jsonpath='{.status.hard.requests\.cpu}' 2>/dev/null || true)" "500m"

for d in high-app low-app; do
  if kubectl -n "$NS" rollout status deployment/"$d" --timeout=10s >/dev/null 2>&1; then
    pass "Deployment $d is fully rolled out"
  else
    fail "Deployment $d is not fully rolled out"
  fi
done

check_eq "high-app priorityClassName" \
  "$(kubectl -n "$NS" get deployment high-app -o jsonpath='{.spec.template.spec.priorityClassName}' 2>/dev/null || true)" "d06-high"
check_eq "low-app priorityClassName" \
  "$(kubectl -n "$NS" get deployment low-app -o jsonpath='{.spec.template.spec.priorityClassName}' 2>/dev/null || true)" "d06-low"

check_eq "high-app CPU request" \
  "$(kubectl -n "$NS" get deployment high-app -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || true)" "200m"
check_eq "low-app CPU request" \
  "$(kubectl -n "$NS" get deployment low-app -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || true)" "50m"

high_ready=$(kubectl -n "$NS" get pods -l app=high-app -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o 'True' | wc -l | tr -d ' ')
low_ready=$(kubectl -n "$NS" get pods -l app=low-app -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o 'True' | wc -l | tr -d ' ')
check_eq "2 high-app Pods are Ready" "$high_ready" "2"
check_eq "4 low-app Pods are Ready" "$low_ready" "4"

for _ in $(seq 1 20); do
  high_used=$(kubectl -n "$NS" get resourcequota high-quota -o jsonpath='{.status.used.pods}' 2>/dev/null || true)
  low_used=$(kubectl -n "$NS" get resourcequota low-quota -o jsonpath='{.status.used.pods}' 2>/dev/null || true)
  [[ "$high_used" == "2" && "$low_used" == "4" ]] && break
  sleep 2
done
check_eq "high-quota counts 2 Pods" "$high_used" "2"
check_eq "low-quota counts 4 Pods" "$low_used" "4"

if kubectl apply --dry-run=server -f - >/dev/null 2>&1 <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: d06-high-probe
  namespace: d06-quota
spec:
  priorityClassName: d06-high
  containers:
    - name: probe
      image: busybox:1.36
      command: ["sleep", "5"]
      resources:
        requests:
          cpu: 10m
          memory: 8Mi
YAML
then
  fail "a third d06-high Pod was admitted despite the quota"
else
  pass "a third d06-high Pod is rejected by quota admission"
fi

summary
