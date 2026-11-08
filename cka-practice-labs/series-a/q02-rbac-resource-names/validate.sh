#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
info "Validating Role, RoleBinding and effective permissions..."
SA="system:serviceaccount:a2-rbac:auditor"

role=$(kubectl -n a2-rbac get role cm-reader -o jsonpath='{.metadata.name}' 2>/dev/null || true)
check_eq "Role cm-reader exists" "$role" "cm-reader"

bind=$(kubectl -n a2-rbac get rolebinding auditor-binding \
  -o jsonpath='{.roleRef.kind}/{.roleRef.name}/{.subjects[0].name}' 2>/dev/null || true)
check_eq "RoleBinding auditor-binding -> Role cm-reader -> SA auditor" \
  "$bind" "Role/cm-reader/auditor"

can() {
  kubectl auth can-i "$@" --as="$SA" >/dev/null 2>&1
}
canout() {
  kubectl auth can-i "$@" --as="$SA" 2>/dev/null || true
}

check_eq "auditor can get configmaps/app-config" \
  "$(canout get configmaps/app-config -n a2-rbac)" "yes"
check_eq "auditor can get configmaps/app-config-2" \
  "$(canout get configmaps/app-config-2 -n a2-rbac)" "yes"
check_eq "auditor cannot get configmaps/other-config" \
  "$(canout get configmaps/other-config -n a2-rbac)" "no"
check_eq "auditor cannot list ConfigMaps (resourceNames cannot scope list)" \
  "$(canout list configmaps -n a2-rbac)" "no"
check_eq "auditor can list Pods in a2-rbac" \
  "$(canout list pods -n a2-rbac)" "yes"
check_eq "auditor can get Pods in a2-rbac" \
  "$(canout get pods -n a2-rbac)" "yes"
check_eq "auditor cannot delete Pods" \
  "$(canout delete pods -n a2-rbac)" "no"
check_eq "auditor cannot read Secrets" \
  "$(canout get secrets -n a2-rbac)" "no"

if can list pods -n default; then
  fail "auditor must not have access outside a2-rbac"
else
  pass "auditor has no access to namespace default"
fi

summary
