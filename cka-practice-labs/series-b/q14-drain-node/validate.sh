#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-b/q14-drain-node"
NS=b14-drain
info "Validating drain, availability and uncordon..."

WORKER=$(cat "$QWORK/node.txt" 2>/dev/null || true)
if [[ -z "$WORKER" ]]; then
  fail "node.txt is missing; re-run setup.sh"
  summary
fi

unsched=$(kubectl get node "$WORKER" -o jsonpath='{.spec.unschedulable}' 2>/dev/null || true)
check_eq "worker $WORKER is schedulable again" "$unsched" ""

ready=$(kubectl get node "$WORKER" \
  -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.status}{"\n"}{end}' 2>/dev/null || true)
check_eq "worker $WORKER is Ready" "$ready" "True"

if kubectl -n "$NS" rollout status deployment/web --timeout=10s >/dev/null 2>&1; then
  pass "Deployment web is fully rolled out"
else
  fail "Deployment web is not fully rolled out"
fi

available=$(kubectl -n "$NS" get deployment web -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)
check_eq "Deployment web has 2 available replicas" "$available" "2"

pods_on_drained=$(kubectl -n "$NS" get pods -l app=web \
  -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' 2>/dev/null | grep -cx "$WORKER" || true)
check_eq "no web Pod was left on the drained node" "$pods_on_drained" "0"

running=$(kubectl -n "$NS" get pods -l app=web -o jsonpath='{.items[*].status.phase}' 2>/dev/null || true)
count=$(tr ' ' '\n' <<<"$running" | grep -c '^Running$' || true)
check_eq "both web Pods are Running" "$count" "2"

summary
