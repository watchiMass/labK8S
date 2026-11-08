#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
NS=d02-rbac
SA="system:serviceaccount:d02-rbac:delegator"
READER="system:serviceaccount:d02-rbac:app-reader"
info "Validating delegated bind permissions..."

check_eq "delegator can create RoleBindings in d02-rbac" \
  "$(kubectl auth can-i create rolebindings -n "$NS" --as="$SA" 2>/dev/null || true)" "yes"

check_eq "delegator can bind clusterroles/d02-pod-reader" \
  "$(kubectl auth can-i bind clusterroles/d02-pod-reader --as="$SA" 2>/dev/null || true)" "yes"

check_eq "delegator cannot bind clusterroles/d02-secret-reader" \
  "$(kubectl auth can-i bind clusterroles/d02-secret-reader --as="$SA" 2>/dev/null || true)" "no"

check_eq "delegator cannot bind clusterroles/cluster-admin" \
  "$(kubectl auth can-i bind clusterroles/cluster-admin --as="$SA" 2>/dev/null || true)" "no"

check_eq "delegator cannot create ClusterRoleBindings" \
  "$(kubectl auth can-i create clusterrolebindings --as="$SA" 2>/dev/null || true)" "no"

role=$(kubectl -n "$NS" get role d02-rolebinding-admin -o name 2>/dev/null || true)
check_eq "Role d02-rolebinding-admin exists" "$role" "role.rbac.authorization.k8s.io/d02-rolebinding-admin"

crb=$(kubectl get clusterrolebinding d02-delegator-binding \
  -o jsonpath='{.roleRef.kind}/{.roleRef.name}/{.subjects[0].name}' 2>/dev/null || true)
check_eq "ClusterRoleBinding binds delegator to d02-delegator" \
  "$crb" "ClusterRole/d02-delegator/delegator"

kubectl delete rolebinding d02-test-allowed d02-test-denied -n "$NS" --ignore-not-found >/dev/null 2>&1 || true
kubectl delete clusterrolebinding d02-test-crb --ignore-not-found >/dev/null 2>&1 || true

if kubectl --as="$SA" -n "$NS" create rolebinding d02-test-allowed \
  --clusterrole=d02-pod-reader --serviceaccount="$NS:app-reader" >/dev/null 2>&1; then
  pass "delegator can create a RoleBinding for d02-pod-reader"
  check_eq "app-reader can list Pods after the delegated binding" \
    "$(kubectl auth can-i list pods -n "$NS" --as="$READER" 2>/dev/null || true)" "yes"
  check_eq "app-reader still cannot read Secrets" \
    "$(kubectl auth can-i get secrets -n "$NS" --as="$READER" 2>/dev/null || true)" "no"
else
  fail "delegator cannot create the allowed RoleBinding"
fi

if kubectl --as="$SA" -n "$NS" create rolebinding d02-test-denied \
  --clusterrole=d02-secret-reader --serviceaccount="$NS:app-reader" >/dev/null 2>&1; then
  fail "delegator was able to bind d02-secret-reader (privilege escalation)"
  kubectl -n "$NS" delete rolebinding d02-test-denied --ignore-not-found >/dev/null 2>&1 || true
else
  pass "delegator cannot bind d02-secret-reader"
fi

if kubectl --as="$SA" create clusterrolebinding d02-test-crb \
  --clusterrole=d02-pod-reader --serviceaccount="$NS:app-reader" >/dev/null 2>&1; then
  fail "delegator was able to create a ClusterRoleBinding"
  kubectl delete clusterrolebinding d02-test-crb --ignore-not-found >/dev/null 2>&1 || true
else
  pass "delegator cannot create a ClusterRoleBinding"
fi

kubectl -n "$NS" delete rolebinding d02-test-allowed d02-test-denied --ignore-not-found >/dev/null 2>&1 || true
summary
