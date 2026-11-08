#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=a7-quota
info "Validating LimitRange, ResourceQuota and workload..."

lr=$(kubectl -n "$NS" get limitrange defaults -o name 2>/dev/null || true)
check_eq "LimitRange defaults exists" "$lr" "limitrange/defaults"

check_eq "LimitRange defaultRequest.cpu" \
  "$(kubectl -n "$NS" get limitrange defaults -o jsonpath='{.spec.limits[0].defaultRequest.cpu}' 2>/dev/null || true)" "100m"
check_eq "LimitRange defaultRequest.memory" \
  "$(kubectl -n "$NS" get limitrange defaults -o jsonpath='{.spec.limits[0].defaultRequest.memory}' 2>/dev/null || true)" "128Mi"
check_eq "LimitRange default.cpu" \
  "$(kubectl -n "$NS" get limitrange defaults -o jsonpath='{.spec.limits[0].default.cpu}' 2>/dev/null || true)" "250m"
check_eq "LimitRange default.memory" \
  "$(kubectl -n "$NS" get limitrange defaults -o jsonpath='{.spec.limits[0].default.memory}' 2>/dev/null || true)" "256Mi"
check_eq "LimitRange max.cpu" \
  "$(kubectl -n "$NS" get limitrange defaults -o jsonpath='{.spec.limits[0].max.cpu}' 2>/dev/null || true)" "500m"
check_eq "LimitRange max.memory" \
  "$(kubectl -n "$NS" get limitrange defaults -o jsonpath='{.spec.limits[0].max.memory}' 2>/dev/null || true)" "512Mi"

rq=$(kubectl -n "$NS" get resourcequota compute -o name 2>/dev/null || true)
check_eq "ResourceQuota compute exists" "$rq" "resourcequota/compute"

hard() {
  kubectl -n "$NS" get resourcequota compute -o jsonpath="$1" 2>/dev/null || true
}
check_eq "quota requests.cpu" "$(hard '{.status.hard.requests\.cpu}')" "1"
check_eq "quota requests.memory" "$(hard '{.status.hard.requests\.memory}')" "1Gi"
check_eq "quota limits.cpu" "$(hard '{.status.hard.limits\.cpu}')" "2"
check_eq "quota limits.memory" "$(hard '{.status.hard.limits\.memory}')" "2Gi"
check_eq "quota pods" "$(hard '{.status.hard.pods}')" "6"
check_eq "quota count/services" "$(hard '{.status.hard.count/services}')" "4"

if kubectl -n "$NS" rollout status deployment/quota-app --timeout=10s >/dev/null 2>&1; then
  pass "Deployment quota-app is fully rolled out"
else
  fail "Deployment quota-app is not fully rolled out"
fi

check_eq "quota-app request cpu" \
  "$(kubectl -n "$NS" get deployment quota-app -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || true)" "200m"
check_eq "quota-app request memory" \
  "$(kubectl -n "$NS" get deployment quota-app -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || true)" "128Mi"
check_eq "quota-app limit cpu" \
  "$(kubectl -n "$NS" get deployment quota-app -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null || true)" "400m"
check_eq "quota-app limit memory" \
  "$(kubectl -n "$NS" get deployment quota-app -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || true)" "256Mi"

ready=$(kubectl -n "$NS" get pods -l app=quota-app -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
count=$(grep -o 'True' <<<"$ready" | wc -l | tr -d ' ')
check_eq "both quota-app Pods are Ready" "$count" "2"

if kubectl apply --dry-run=server -f - >/dev/null 2>&1 <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: quota-probe
  namespace: a7-quota
spec:
  containers:
    - name: probe
      image: busybox:1.36
      command: ["sleep", "5"]
      resources:
        requests:
          cpu: 600m
YAML
then
  fail "a Pod requesting 600m CPU was not rejected by the LimitRange"
else
  pass "a Pod requesting 600m CPU is rejected by admission"
fi

summary
