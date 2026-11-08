#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=c9-job
info "Validating Job configuration and completion..."

if kubectl -n "$NS" get job batch >/dev/null 2>&1; then
  pass "Job batch exists"
else
  fail "Job batch is missing"
  summary
fi

completions=$(kubectl -n "$NS" get job batch -o jsonpath='{.spec.completions}' 2>/dev/null || true)
parallelism=$(kubectl -n "$NS" get job batch -o jsonpath='{.spec.parallelism}' 2>/dev/null || true)
backoff=$(kubectl -n "$NS" get job batch -o jsonpath='{.spec.backoffLimit}' 2>/dev/null || true)
deadline=$(kubectl -n "$NS" get job batch -o jsonpath='{.spec.activeDeadlineSeconds}' 2>/dev/null || true)
check_eq "completions is 4" "$completions" "4"
check_eq "parallelism is 2" "$parallelism" "2"
check_eq "backoffLimit is 2" "$backoff" "2"
check_eq "activeDeadlineSeconds is 180" "$deadline" "180"

image=$(kubectl -n "$NS" get job batch \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
restart=$(kubectl -n "$NS" get job batch \
  -o jsonpath='{.spec.template.spec.restartPolicy}' 2>/dev/null || true)
check_eq "image is busybox:1.36" "$image" "busybox:1.36"
check_eq "restartPolicy is Never" "$restart" "Never"

succeeded="0"
for _ in $(seq 1 120); do
  succeeded=$(kubectl -n "$NS" get job batch -o jsonpath='{.status.succeeded}' 2>/dev/null || true)
  completions_status=$(kubectl -n "$NS" get job batch -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || true)
  [[ "$succeeded" == "4" ]] && break
  sleep 2
done
check_eq "Job reports 4 succeeded Pods" "$succeeded" "4"

complete=$(kubectl -n "$NS" get job batch \
  -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || true)
check_eq "Job has Completed condition True" "$complete" "True"

failed=$(kubectl -n "$NS" get job batch -o jsonpath='{.status.failed}' 2>/dev/null || true)
if [[ -z "$failed" || "$failed" == "0" ]]; then
  pass "no failed Job Pods"
else
  fail "Job reports $failed failed Pods"
fi

completed_pods=$(kubectl -n "$NS" get pods -l job-name=batch \
  -o jsonpath='{.items[*].status.phase}' 2>/dev/null | tr ' ' '\n' | grep -c '^Succeeded$' || true)
check_eq "4 Pods are in Succeeded phase" "$completed_pods" "4"

summary
