#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-c/q16-operator-kustomize"
NS=c16-operator
SA="system:serviceaccount:c16-operator:operator"
info "Validating operator RBAC, base changes, Student and logs..."

check_eq "operator can list students" \
  "$(kubectl auth can-i list students.cka.example.com -n "$NS" --as="$SA" 2>/dev/null || true)" "yes"
check_eq "operator can list courses" \
  "$(kubectl auth can-i list courses.cka.example.com -n "$NS" --as="$SA" 2>/dev/null || true)" "yes"
check_eq "operator can still get students" \
  "$(kubectl auth can-i get students.cka.example.com -n "$NS" --as="$SA" 2>/dev/null || true)" "yes"

crb=$(kubectl get clusterrolebinding -o jsonpath='{range .items[*]}{.subjects[0].name}{"\n"}{end}' 2>/dev/null \
  | grep -x 'operator' || true)
if [[ -n "$crb" ]]; then
  fail "a ClusterRoleBinding still grants the operator cluster-wide access"
else
  pass "operator access stays namespaced (no ClusterRoleBinding)"
fi

if kubectl -n "$NS" get student student4 >/dev/null 2>&1; then
  pass "Student student4 exists in c16-operator"
else
  fail "Student student4 is missing"
fi

if kubectl -n "$NS" rollout status deployment/operator --timeout=10s >/dev/null 2>&1; then
  pass "operator Deployment is fully rolled out"
else
  fail "operator Deployment is not fully rolled out"
fi

sa=$(kubectl -n "$NS" get deployment operator \
  -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null || true)
check_eq "operator Deployment uses ServiceAccount operator" "$sa" "operator"

base_render=$(kubectl kustomize "$QWORK/base" 2>/dev/null || true)
if grep -q 'student4' <<<"$base_render"; then
  pass "the Kustomize base renders student4"
else
  fail "the Kustomize base does not render student4"
fi
if grep -q -- '- list' <<<"$base_render"; then
  pass "the Kustomize base renders the list verb"
else
  fail "the Kustomize base does not render the list verb"
fi

logs=""
for _ in $(seq 1 60); do
  logs=$(kubectl -n "$NS" logs deployment/operator --tail=80 2>/dev/null || true)
  if grep -q 'OK list students' <<<"$logs" && grep -q 'OK list courses' <<<"$logs"; then
    break
  fi
  sleep 3
done
if grep -q 'OK list students' <<<"$logs" && grep -q 'OK list courses' <<<"$logs"; then
  pass "operator logs show successful list calls for students and courses"
else
  fail "operator logs still do not show successful list calls for both resources"
fi

summary
