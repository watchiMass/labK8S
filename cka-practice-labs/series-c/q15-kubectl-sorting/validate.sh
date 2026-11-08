#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-c/q15-kubectl-sorting"
info "Validating sorting scripts and their output order..."

check_script() { # file sort-field expected-sort-field
  local file="$1" field="$2"
  if [[ ! -s "$file" ]]; then
    fail "$(basename "$file") is missing"
    return
  fi
  pass "$(basename "$file") exists"

  if ! grep -q -- 'kubectl get pods' "$file"; then
    fail "$(basename "$file") does not call kubectl get pods"
    return
  fi
  if ! grep -Eq -- '(-A|--all-namespaces)' "$file"; then
    fail "$(basename "$file") does not use all namespaces"
  else
    pass "$(basename "$file") uses all namespaces"
  fi
  if grep -q -- "--sort-by=$field" "$file"; then
    pass "$(basename "$file") uses --sort-by=$field"
  else
    fail "$(basename "$file") does not use --sort-by=$field"
  fi

  if ! output=$(bash "$file" 2>/dev/null) || [[ -z "$output" ]]; then
    fail "$(basename "$file") does not run or produced no output"
    return
  fi
  pass "$(basename "$file") runs and produces output"

  if grep -q '^NAMESPACE' <<<"$output"; then
    actual=$(awk 'NR>1 {print $2}' <<<"$output" | head -n 10)
  else
    actual=$(awk '{print $2}' <<<"$output" | head -n 10)
  fi
  expected=$(kubectl get pods -A --sort-by="$field" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | head -n 10)
  if [[ "$actual" == "$expected" ]]; then
    pass "$(basename "$file") output is ordered by $field"
  else
    fail "$(basename "$file") output order does not match kubectl --sort-by=$field"
  fi
}

check_script "$QWORK/find_pods.sh" ".metadata.creationTimestamp"
check_script "$QWORK/find_pods_uid.sh" ".metadata.uid"

summary
