#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
info "Validating aggregated ClusterRole and namespaced binding..."
SA="system:serviceaccount:a3-agg:metrics-agent"

agg_label=$(kubectl get clusterrole metrics-reader \
  -o jsonpath='{.aggregationRule.clusterRoleSelectors[0].matchLabels.rbac\.cka/aggregate-to-metrics-reader}' 2>/dev/null || true)
check_eq "metrics-reader aggregates on the required label" "$agg_label" "true"

own_rules=$(kubectl get clusterrole metrics-reader -o jsonpath='{.rules}' 2>/dev/null || true)
check_eq "metrics-reader has no rules of its own" "$own_rules" ""

label_pods=$(kubectl get clusterrole metrics-pods \
  -o jsonpath='{.metadata.labels.rbac\.cka/aggregate-to-metrics-reader}' 2>/dev/null || true)
check_eq "metrics-pods carries the aggregation label" "$label_pods" "true"

label_nodes=$(kubectl get clusterrole metrics-nodes \
  -o jsonpath='{.metadata.labels.rbac\.cka/aggregate-to-metrics-reader}' 2>/dev/null || true)
check_eq "metrics-nodes carries the aggregation label" "$label_nodes" "true"

rules=$(kubectl get clusterrole metrics-reader -o jsonpath='{range .rules[*]}{.resources[*]}{"\n"}{end}' 2>/dev/null || true)
for _ in $(seq 1 15); do
  rules=$(kubectl get clusterrole metrics-reader -o jsonpath='{range .rules[*]}{.resources[*]}{"\n"}{end}' 2>/dev/null || true)
  if grep -qx 'pods' <<<"$rules" && grep -qx 'nodes' <<<"$rules"; then
    break
  fi
  sleep 2
done
check_contains "aggregated rules include pods" "$rules" "pods"
check_contains "aggregated rules include nodes" "$rules" "nodes"

bind=$(kubectl -n a3-agg get rolebinding metrics-agent-binding \
  -o jsonpath='{.roleRef.kind}/{.roleRef.name}/{.subjects[0].name}' 2>/dev/null || true)
check_eq "RoleBinding binds metrics-agent to ClusterRole metrics-reader" \
  "$bind" "ClusterRole/metrics-reader/metrics-agent"

crb=$(kubectl get clusterrolebinding -o jsonpath='{range .items[*]}{.roleRef.name}/{.subjects[0].name}{"\n"}{end}' 2>/dev/null \
  | grep 'metrics-reader/metrics-agent' || true)
if [[ -n "$crb" ]]; then
  fail "a ClusterRoleBinding grants cluster-wide access; use a RoleBinding"
else
  pass "no ClusterRoleBinding grants metrics-agent cluster-wide access"
fi

check_eq "metrics-agent can list Pods in a3-agg" \
  "$(kubectl auth can-i list pods -n a3-agg --as="$SA" 2>/dev/null || true)" "yes"
check_eq "metrics-agent cannot list Pods in default" \
  "$(kubectl auth can-i list pods -n default --as="$SA" 2>/dev/null || true)" "no"
check_eq "metrics-agent cannot list Nodes (RoleBinding does not grant cluster-scoped access)" \
  "$(kubectl auth can-i list nodes --as="$SA" 2>/dev/null || true)" "no"

summary
