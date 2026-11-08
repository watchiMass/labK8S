#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=d12-job
info "Validating indexed Job configuration and per-index completion..."

if kubectl -n "$NS" get job indexed-batch >/dev/null 2>&1; then
  pass "Job indexed-batch exists"
else
  fail "Job indexed-batch is missing"
  summary
fi

mode=$(kubectl -n "$NS" get job indexed-batch -o jsonpath='{.spec.completionMode}' 2>/dev/null || true)
completions=$(kubectl -n "$NS" get job indexed-batch -o jsonpath='{.spec.completions}' 2>/dev/null || true)
parallelism=$(kubectl -n "$NS" get job indexed-batch -o jsonpath='{.spec.parallelism}' 2>/dev/null || true)
backoff=$(kubectl -n "$NS" get job indexed-batch -o jsonpath='{.spec.backoffLimit}' 2>/dev/null || true)
deadline=$(kubectl -n "$NS" get job indexed-batch -o jsonpath='{.spec.activeDeadlineSeconds}' 2>/dev/null || true)
check_eq "completionMode is Indexed" "$mode" "Indexed"
check_eq "completions is 6" "$completions" "6"
check_eq "parallelism is 3" "$parallelism" "3"
check_eq "backoffLimit is 0" "$backoff" "0"
check_eq "activeDeadlineSeconds is 180" "$deadline" "180"

image=$(kubectl -n "$NS" get job indexed-batch \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
restart=$(kubectl -n "$NS" get job indexed-batch \
  -o jsonpath='{.spec.template.spec.restartPolicy}' 2>/dev/null || true)
check_eq "image is busybox:1.36" "$image" "busybox:1.36"
check_eq "restartPolicy is Never" "$restart" "Never"

succeeded="0"
for _ in $(seq 1 120); do
  succeeded=$(kubectl -n "$NS" get job indexed-batch -o jsonpath='{.status.succeeded}' 2>/dev/null || true)
  [[ "$succeeded" == "6" ]] && break
  sleep 2
done
check_eq "Job reports 6 succeeded Pods" "$succeeded" "6"

complete=$(kubectl -n "$NS" get job indexed-batch \
  -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || true)
check_eq "Job has Complete=True" "$complete" "True"

completed_indexes=$(kubectl -n "$NS" get job indexed-batch \
  -o jsonpath='{.status.completedIndexes}' 2>/dev/null || true)
if [[ -n "$completed_indexes" ]]; then
  pass "Job status reports completedIndexes ($completed_indexes)"
else
  fail "Job status has no completedIndexes"
fi

seen=""
for pod in $(kubectl -n "$NS" get pods -l job-name=indexed-batch \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null); do
  phase=$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  [[ "$phase" == "Succeeded" ]] || continue
  log=$(kubectl -n "$NS" logs "$pod" 2>/dev/null || true)
  if idx=$(grep -oE '^index=[0-5]$' <<<"$log" | head -n1); then
    seen="$seen ${idx#index=}"
  fi
done

missing=""
for i in 0 1 2 3 4 5; do
  if ! tr ' ' '\n' <<<"$seen" | grep -qx "$i"; then
    missing="$missing $i"
  fi
done
if [[ -z "$missing" ]]; then
  pass "Pod logs collectively cover completion indices 0 through 5"
else
  fail "missing completion indices in Pod logs:$missing"
fi

summary
