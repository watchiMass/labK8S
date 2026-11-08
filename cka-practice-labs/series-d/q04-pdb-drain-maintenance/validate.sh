#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
NS=d04-maint
info "Validating PDB-aware maintenance and final state..."

WORKER=$(cat "$QWORK/node.txt" 2>/dev/null || true)
if [[ -z "$WORKER" ]]; then
  fail "node.txt is missing; re-run setup.sh"
  summary
fi

unsched=$(kubectl get node "$WORKER" -o jsonpath='{.spec.unschedulable}' 2>/dev/null || true)
check_eq "worker $WORKER is schedulable again" "$unsched" ""

readycond=$(kubectl get node "$WORKER" \
  -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.status}{"\n"}{end}' 2>/dev/null || true)
check_eq "worker $WORKER is Ready" "$readycond" "True"

replicas=$(kubectl -n "$NS" get deployment web -o jsonpath='{.spec.replicas}' 2>/dev/null || true)
check_eq "Deployment is back to 3 replicas" "$replicas" "3"

available=$(kubectl -n "$NS" get deployment web -o jsonpath='{.status.availableReplicas}' 2>/dev/null || true)
updated=$(kubectl -n "$NS" get deployment web -o jsonpath='{.status.updatedReplicas}' 2>/dev/null || true)
check_eq "Deployment has 3 available replicas" "$available" "3"
check_eq "Deployment has 3 updated replicas" "$updated" "3"

if kubectl -n "$NS" rollout status deployment/web --timeout=10s >/dev/null 2>&1; then
  pass "Deployment web rollout is complete"
else
  fail "Deployment web rollout is not complete"
fi

pdb_min=$(kubectl -n "$NS" get pdb web-pdb -o jsonpath='{.spec.minAvailable}' 2>/dev/null || true)
check_eq "PDB minAvailable is still 3" "$pdb_min" "3"

for _ in $(seq 1 30); do
  healthy=$(kubectl -n "$NS" get pdb web-pdb -o jsonpath='{.status.currentHealthy}' 2>/dev/null || true)
  allowed=$(kubectl -n "$NS" get pdb web-pdb -o jsonpath='{.status.disruptionsAllowed}' 2>/dev/null || true)
  [[ "$healthy" == "3" && "$allowed" == "0" ]] && break
  sleep 2
done
check_eq "PDB reports 3 healthy Pods" "$healthy" "3"
check_eq "PDB reports 0 allowed disruptions" "$allowed" "0"

expected=$(kubectl -n "$NS" get pdb web-pdb -o jsonpath='{.status.expectedPods}' 2>/dev/null || true)
check_eq "PDB expects 3 Pods" "$expected" "3"

left=$(kubectl -n "$NS" get pods -l app=web \
  -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' 2>/dev/null | grep -cx "$WORKER" || true)
check_eq "no web Pod remains on the maintained node" "$left" "0"

running=$(kubectl -n "$NS" get pods -l app=web -o jsonpath='{.items[*].status.phase}' 2>/dev/null | tr ' ' '\n' | grep -c '^Running$' || true)
check_eq "all 3 web Pods are Running" "$running" "3"

summary
