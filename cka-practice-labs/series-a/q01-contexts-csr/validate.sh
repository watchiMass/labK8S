#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
KC="$QWORK/dev-anna.kubeconfig"
info "Validating client certificate, kubeconfig and RBAC in $QWORK..."

for f in dev-anna.key dev-anna.csr dev-anna.crt dev-anna.kubeconfig; do
  if [[ -s "$QWORK/$f" ]]; then
    pass "file $f exists and is non-empty"
  else
    fail "missing or empty file $f"
  fi
done

if [[ -s "$QWORK/dev-anna.crt" ]]; then
  subject=$(openssl x509 -in "$QWORK/dev-anna.crt" -noout -subject 2>/dev/null || true)
  check_contains "certificate subject contains dev-anna" "$subject" "dev-anna"
  check_contains "certificate subject contains dev-team" "$subject" "dev-team"

  tmpdir=$(mktemp -d)
  if openssl x509 -in "$QWORK/dev-anna.crt" -noout -pubkey >"$tmpdir/cert.pub" 2>/dev/null \
     && openssl pkey -in "$QWORK/dev-anna.key" -pubout >"$tmpdir/key.pub" 2>/dev/null \
     && cmp -s "$tmpdir/cert.pub" "$tmpdir/key.pub"; then
    pass "private key matches the issued certificate"
  else
    fail "private key does not match the issued certificate"
  fi
  rm -rf "$tmpdir"
fi

approved=$(kubectl get csr dev-anna -o jsonpath='{.status.conditions[?(@.type=="Approved")].status}' 2>/dev/null || true)
check_eq "CSR dev-anna is approved" "$approved" "True"

if [[ -s "$KC" ]]; then
  ctx=$(kubectl --kubeconfig "$KC" config current-context 2>/dev/null || true)
  check_eq "kubeconfig current-context is dev-anna@cka" "$ctx" "dev-anna@cka"

  ns=$(kubectl --kubeconfig "$KC" config view --minify -o jsonpath='{..namespace}' 2>/dev/null || true)
  check_eq "kubeconfig context namespace is a1-dev" "$ns" "a1-dev"

  if kubectl --kubeconfig "$KC" get pods -n a1-dev >/dev/null 2>&1; then
    pass "dev-anna kubeconfig can reach the API"
  else
    fail "dev-anna kubeconfig cannot reach the API (bad cert/CA/server?)"
  fi

  can=$(kubectl --kubeconfig "$KC" auth can-i list pods -n a1-dev 2>/dev/null || true)
  check_eq "dev-anna can list Pods in a1-dev" "$can" "yes"

  can=$(kubectl --kubeconfig "$KC" auth can-i get secrets -n a1-dev 2>/dev/null || true)
  check_eq "dev-anna cannot read Secrets in a1-dev" "$can" "no"

  can=$(kubectl --kubeconfig "$KC" auth can-i list pods -n default 2>/dev/null || true)
  check_eq "dev-anna cannot list Pods in default" "$can" "no"
else
  fail "dev-anna.kubeconfig missing; skipping access checks"
fi

rb=$(kubectl -n a1-dev get rolebinding dev-anna-view \
  -o jsonpath='{.roleRef.kind}/{.roleRef.name}/{.subjects[0].name}' 2>/dev/null || true)
check_eq "RoleBinding dev-anna-view binds dev-anna to ClusterRole view" \
  "$rb" "ClusterRole/view/dev-anna"

summary
