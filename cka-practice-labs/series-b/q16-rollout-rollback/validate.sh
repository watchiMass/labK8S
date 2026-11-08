#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=b16-rollout
info "Validating rollback and rollout health..."

image=$(kubectl -n "$NS" get deployment api \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
check_eq "Deployment image is back to nginx:1-alpine" "$image" "nginx:1-alpine"

if kubectl -n "$NS" rollout status deployment/api --timeout=10s >/dev/null 2>&1; then
  pass "rollout completed"
else
  fail "rollout has not completed"
fi

replicas=$(kubectl -n "$NS" get deployment api -o jsonpath='{.spec.replicas}' 2>/dev/null || true)
available=$(kubectl -n "$NS" get deployment api -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)
updated=$(kubectl -n "$NS" get deployment api -o jsonpath='{.status.updatedReplicas}' 2>/dev/null || true)
check_eq "desired replicas is 3" "$replicas" "3"
check_eq "available replicas is 3" "$available" "3"
check_eq "updated replicas is 3" "$updated" "3"

revision=$(kubectl -n "$NS" get deployment api \
  -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}' 2>/dev/null || true)
if [[ "${revision:-0}" -ge 3 ]]; then
  pass "Deployment revision advanced to $revision after the rollback"
else
  fail "Deployment revision is ${revision:-0}; expected at least 3 (rollback workflow)"
fi

bad=0
while IFS= read -r img; do
  [[ -z "$img" ]] && continue
  [[ "$img" == "nginx:1-alpine" ]] || bad=$((bad + 1))
done < <(kubectl -n "$NS" get pods -l app=api \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}' 2>/dev/null)
check_eq "all Pods run nginx:1-alpine" "$bad" "0"

ready=$(kubectl -n "$NS" get pods -l app=api \
  -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
count=$(grep -o 'True' <<<"$ready" | wc -l | tr -d ' ')
check_eq "all 3 Pods are Ready" "$count" "3"

summary
