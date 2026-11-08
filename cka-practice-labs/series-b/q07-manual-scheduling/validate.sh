#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-b/q07-manual-scheduling"
info "Validating scheduler restoration and manual scheduling..."

WORKER=$(cat "$QWORK/node.txt" 2>/dev/null || true)
[[ -n "$WORKER" ]] || fail "node.txt is missing; re-run setup.sh"

for _ in $(seq 1 30); do
  sched=$(kubectl -n kube-system get pods -l component=kube-scheduler \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)
  [[ "$sched" == "Running" ]] && break
  sleep 2
done
check_eq "kube-scheduler static Pod is Running" "$sched" "Running"

if [[ -f /etc/kubernetes/manifests/kube-scheduler.yaml ]]; then
  pass "kube-scheduler static manifest is back in the manifests directory"
else
  fail "kube-scheduler static manifest is still missing"
fi

for _ in $(seq 1 60); do
  phase=$(kubectl get pod manual-schedule -n default -o jsonpath='{.status.phase}' 2>/dev/null || true)
  [[ "$phase" == "Running" ]] && break
  sleep 2
done
check_eq "manual-schedule Pod is Running" "$phase" "Running"

node=$(kubectl get pod manual-schedule -n default -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)
check_eq "manual-schedule runs on the requested worker" "$node" "$WORKER"

for _ in $(seq 1 60); do
  phase2=$(kubectl get pod manual-schedule2 -n default -o jsonpath='{.status.phase}' 2>/dev/null || true)
  [[ "$phase2" == "Running" ]] && break
  sleep 2
done
check_eq "manual-schedule2 Pod is Running" "$phase2" "Running"

node2=$(kubectl get pod manual-schedule2 -n default -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)
if [[ -n "$node2" ]]; then
  pass "kube-scheduler assigned manual-schedule2 to $node2"
else
  fail "manual-schedule2 has no nodeName (scheduler not restored?)"
fi

summary
