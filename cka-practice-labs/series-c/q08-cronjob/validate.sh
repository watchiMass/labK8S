#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=c8-cron
info "Validating CronJob fields and a successful run..."

if kubectl -n "$NS" get cronjob report >/dev/null 2>&1; then
  pass "CronJob report exists"
else
  fail "CronJob report is missing"
  summary
fi

schedule=$(kubectl -n "$NS" get cronjob report -o jsonpath='{.spec.schedule}' 2>/dev/null || true)
check_eq "schedule is every minute" "$schedule" "*/1 * * * *"

image=$(kubectl -n "$NS" get cronjob report \
  -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}' 2>/dev/null || true)
check_eq "image is busybox:1.36" "$image" "busybox:1.36"

cmd=$(kubectl -n "$NS" get cronjob report \
  -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].command[*]}' 2>/dev/null || true)
check_contains "command prints the date" "$cmd" "date"

cp=$(kubectl -n "$NS" get cronjob report -o jsonpath='{.spec.concurrencyPolicy}' 2>/dev/null || true)
check_eq "concurrencyPolicy is Forbid" "$cp" "Forbid"

deadline=$(kubectl -n "$NS" get cronjob report -o jsonpath='{.spec.startingDeadlineSeconds}' 2>/dev/null || true)
check_eq "startingDeadlineSeconds is 30" "$deadline" "30"

ok_hist=$(kubectl -n "$NS" get cronjob report -o jsonpath='{.spec.successfulJobsHistoryLimit}' 2>/dev/null || true)
fail_hist=$(kubectl -n "$NS" get cronjob report -o jsonpath='{.spec.failedJobsHistoryLimit}' 2>/dev/null || true)
check_eq "successfulJobsHistoryLimit is 2" "$ok_hist" "2"
check_eq "failedJobsHistoryLimit is 1" "$fail_hist" "1"

backoff=$(kubectl -n "$NS" get cronjob report \
  -o jsonpath='{.spec.jobTemplate.spec.backoffLimit}' 2>/dev/null || true)
check_eq "job backoffLimit is 1" "$backoff" "1"

restart=$(kubectl -n "$NS" get cronjob report \
  -o jsonpath='{.spec.jobTemplate.spec.template.spec.restartPolicy}' 2>/dev/null || true)
check_eq "restartPolicy is Never" "$restart" "Never"

suspended=$(kubectl -n "$NS" get cronjob report -o jsonpath='{.spec.suspend}' 2>/dev/null || true)
check_eq "CronJob is not suspended" "$suspended" ""

succeeded="0"
for _ in $(seq 1 75); do
  for job in $(kubectl -n "$NS" get jobs -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    n=$(kubectl -n "$NS" get job "$job" -o jsonpath='{.status.succeeded}' 2>/dev/null || true)
    if [[ "${n:-0}" -ge 1 ]]; then
      succeeded="$n"
      break 2
    fi
  done
  sleep 2
done
if [[ "$succeeded" -ge 1 ]]; then
  pass "at least one CronJob run completed successfully"
else
  fail "no successful Job was observed within 150 seconds"
fi

last=""
for _ in $(seq 1 20); do
  last=$(kubectl -n "$NS" get cronjob report -o jsonpath='{.status.lastSuccessfulTime}' 2>/dev/null || true)
  [[ -n "$last" ]] && break
  sleep 2
done
if [[ -n "$last" ]]; then
  pass "CronJob status records lastSuccessfulTime ($last)"
else
  fail "CronJob status has no lastSuccessfulTime"
fi

summary
