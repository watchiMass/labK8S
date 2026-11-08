#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
NS=d16-token
info "Validating bound ServiceAccount token lifecycle..."

rb=$(kubectl -n "$NS" get rolebinding bound-reader-binding \
  -o jsonpath='{.roleRef.kind}/{.roleRef.name}/{.subjects[0].name}' 2>/dev/null || true)
check_eq "bound-reader RoleBinding is present" \
  "$rb" "Role/bound-reader/bound-reader"

if kubectl -n "$NS" get pod token-target >/dev/null 2>&1; then
  fail "Pod token-target still exists"
else
  pass "Pod token-target has been deleted"
fi

if [[ -s "$QWORK/token.txt" ]]; then
  pass "token.txt exists"
else
  fail "token.txt is missing"
  summary
fi

if [[ -s "$QWORK/before.txt" ]] && grep -q 'token-target' "$QWORK/before.txt"; then
  pass "before.txt shows the Pod listing through the bound token"
else
  fail "before.txt does not show the successful token-based Pod listing"
fi

if [[ -s "$QWORK/after.txt" ]] \
   && grep -Eqi 'unauthorized|401|error|forbidden' "$QWORK/after.txt"; then
  pass "after.txt records the rejected request"
else
  fail "after.txt does not record a rejected request"
fi

TOKEN=$(tr -d '\r\n' <"$QWORK/token.txt")
if [[ -z "$TOKEN" ]]; then
  fail "token.txt is empty"
  summary
fi

if kubectl --token="$TOKEN" get pods -n "$NS" >/dev/null 2>&1; then
  fail "the bound token is still accepted after the Pod was deleted"
else
  pass "the bound token is rejected after the Pod was deleted"
fi

check_eq "bound-reader can still list Pods with its normal identity" \
  "$(kubectl auth can-i list pods -n "$NS" --as="system:serviceaccount:d16-token:bound-reader" 2>/dev/null || true)" "yes"

summary
