#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=a15-pdb
info "Validating PodDisruptionBudget..."

if kubectl -n "$NS" get pdb api-pdb >/dev/null 2>&1; then
  pass "PodDisruptionBudget api-pdb exists"
else
  fail "PodDisruptionBudget api-pdb is missing"
fi

min=$(kubectl -n "$NS" get pdb api-pdb -o jsonpath='{.spec.minAvailable}' 2>/dev/null || true)
check_eq "PDB minAvailable is 2" "$min" "2"

max=$(kubectl -n "$NS" get pdb api-pdb -o jsonpath='{.spec.maxUnavailable}' 2>/dev/null || true)
check_eq "PDB does not use maxUnavailable" "$max" ""

selector=$(kubectl -n "$NS" get pdb api-pdb \
  -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null || true)
check_eq "PDB selects app=api" "$selector" "api"

if kubectl -n "$NS" rollout status deployment/api --timeout=10s >/dev/null 2>&1; then
  pass "Deployment api is fully rolled out"
else
  fail "Deployment api is not fully rolled out"
fi

for _ in $(seq 1 15); do
  allowed=$(kubectl -n "$NS" get pdb api-pdb -o jsonpath='{.status.disruptionsAllowed}' 2>/dev/null || true)
  [[ "$allowed" == "2" ]] && break
  sleep 2
done
check_eq "PDB allows 2 disruptions" "$allowed" "2"

expected=$(kubectl -n "$NS" get pdb api-pdb -o jsonpath='{.status.expectedPods}' 2>/dev/null || true)
check_eq "PDB expects 4 Pods" "$expected" "4"

healthy=$(kubectl -n "$NS" get pdb api-pdb -o jsonpath='{.status.currentHealthy}' 2>/dev/null || true)
check_eq "PDB sees 4 healthy Pods" "$healthy" "4"

summary
