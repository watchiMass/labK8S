#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-b/q12-taint-toleration"
NS=b12-pending
info "Validating taint, toleration and Pod placement..."

WORKER=$(cat "$QWORK/node.txt" 2>/dev/null || true)
[[ -n "$WORKER" ]] || fail "node.txt is missing; re-run setup.sh"

taint=$(kubectl get node "$WORKER" \
  -o jsonpath='{range .spec.taints[?(@.key=="dedicated")]}{.value}/{.effect}{"\n"}{end}' 2>/dev/null || true)
check_contains "worker still has the dedicated=cka:NoSchedule taint" "$taint" "cka/NoSchedule"

selector=$(kubectl -n "$NS" get deployment gpu-worker \
  -o jsonpath='{.spec.template.spec.nodeSelector.dedicated}' 2>/dev/null || true)
check_eq "nodeSelector dedicated=cka is unchanged" "$selector" "cka"

tols=$(kubectl -n "$NS" get deployment gpu-worker \
  -o jsonpath='{range .spec.template.spec.tolerations[*]}{.key}/{.operator}/{.value}/{.effect}{"\n"}{end}' 2>/dev/null || true)
if grep -Eq '^dedicated/(Equal|Exists)/(cka)?/NoSchedule$' <<<"$tols"; then
  pass "Deployment tolerates dedicated=cka:NoSchedule"
else
  fail "Deployment does not have a matching toleration (got: $tols)"
fi

for _ in $(seq 1 60); do
  phase=$(kubectl -n "$NS" get pods -l app=gpu-worker -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)
  [[ "$phase" == "Running" ]] && break
  sleep 2
done
check_eq "gpu-worker Pod is Running" "$phase" "Running"

node=$(kubectl -n "$NS" get pods -l app=gpu-worker -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null || true)
check_eq "gpu-worker Pod runs on the target worker" "$node" "$WORKER"

if kubectl -n "$NS" rollout status deployment/gpu-worker --timeout=10s >/dev/null 2>&1; then
  pass "Deployment gpu-worker is fully rolled out"
else
  fail "Deployment gpu-worker is not fully rolled out"
fi

summary
