#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_root_or_sudo
QWORK="$CKA_WORKROOT/series-b/q05-cert-expiration"
CERT=/etc/kubernetes/pki/apiserver.crt
info "Validating certificate expiration and renewal command..."

if $SUDO test -s "$CERT"; then
  pass "kube-apiserver certificate exists"
  raw=$($SUDO openssl x509 -in "$CERT" -noout -enddate 2>/dev/null || true)
else
  fail "kube-apiserver certificate is missing"
  raw=""
fi

expected_date=$(sed -E 's/^notAfter=//' <<<"$raw" | tr -s ' ' | sed -E 's/^ //; s/ $//')
if [[ -n "$expected_date" ]]; then
  if [[ -s "$QWORK/expiration" ]] && tr -s ' ' <"$QWORK/expiration" | grep -Fq "$expected_date"; then
    pass "expiration file matches the certificate notAfter date"
  else
    fail "expiration file does not contain the certificate date '$expected_date'"
  fi
else
  fail "could not read the certificate expiration date"
fi

if [[ -s "$QWORK/kubeadm-renew-certs.sh" ]]; then
  pass "kubeadm-renew-certs.sh exists"
  if grep -Eq 'kubeadm[[:space:]]+certs[[:space:]]+renew[[:space:]]+apiserver' "$QWORK/kubeadm-renew-certs.sh"; then
    pass "script renews the apiserver certificate"
  else
    fail "script does not contain 'kubeadm certs renew apiserver'"
  fi
  if grep -Eq 'kubeadm[[:space:]]+certs[[:space:]]+renew[[:space:]]+all' "$QWORK/kubeadm-renew-certs.sh"; then
    fail "script renews everything instead of only the apiserver certificate"
  else
    pass "script does not renew all certificates"
  fi
else
  fail "kubeadm-renew-certs.sh is missing"
fi

if command -v kubeadm >/dev/null 2>&1; then
  if $SUDO kubeadm certs check-expiration 2>/dev/null | grep -Eq "apiserver.*$expected_date"; then
    pass "kubeadm certs check-expiration reports the same date"
  else
    warn "Could not match the date in kubeadm's output; check it manually."
  fi
fi

summary
