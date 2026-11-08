#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
FILE="$QWORK/certificate-info.txt"
info "Validating kubelet certificate report..."

WORKER=$(cat "$QWORK/node.txt" 2>/dev/null || true)
[[ -n "$WORKER" ]] || fail "node.txt is missing; re-run setup.sh"

if [[ -s "$FILE" ]]; then
  pass "certificate-info.txt exists"
else
  fail "certificate-info.txt is missing"
  summary
fi

ci=$(grep -iE '^client issuer:' "$FILE" | head -n1 | sed -E 's/^[^:]*:[[:space:]]*//' || true)
ce=$(grep -iE '^client eku:' "$FILE" | head -n1 | sed -E 's/^[^:]*:[[:space:]]*//' || true)
si=$(grep -iE '^server issuer:' "$FILE" | head -n1 | sed -E 's/^[^:]*:[[:space:]]*//' || true)
se=$(grep -iE '^server eku:' "$FILE" | head -n1 | sed -E 's/^[^:]*:[[:space:]]*//' || true)

if [[ -n "$ci" && "${ci,,}" == *"kubernetes"* ]]; then
  pass "client issuer looks like the cluster CA (kubernetes)"
else
  fail "client issuer is missing or does not look like the cluster CA (got '$ci')"
fi

if [[ -n "$si" && ( "${si,,}" == *"kubernetes"* || ( -n "$WORKER" && "${si,,}" == *"${WORKER,,}"* ) ) ]]; then
  pass "server issuer is plausible (cluster CA or self-signed by the node)"
else
  fail "server issuer is missing or implausible (got '$si')"
fi

if [[ "${ce,,}" == *"client authentication"* ]]; then
  pass "client certificate EKU is client authentication"
else
  fail "client EKU does not mention client authentication (got '$ce')"
fi

if [[ "${se,,}" == *"server authentication"* ]]; then
  pass "server certificate EKU is server authentication"
else
  fail "server EKU does not mention server authentication (got '$se')"
fi

if [[ -n "$WORKER" ]] && ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
  "$WORKER" "sudo -n test -s /var/lib/kubelet/pki/kubelet-client-current.pem" >/dev/null 2>&1; then
  remote_issuer=$(ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
    "$WORKER" "sudo -n openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -issuer" 2>/dev/null \
    | sed -E 's/^issuer=//' | tr -s ' ' || true)
  remote_cn=$(sed -nE 's/.*CN[[:space:]]*=[[:space:]]*([^,]+).*/\1/p' <<<"$remote_issuer" | head -n1)
  if [[ -n "$remote_cn" ]] && grep -Fqi "$remote_cn" <<<"$ci"; then
    pass "reported client issuer matches the worker certificate (CN=$remote_cn)"
  else
    fail "reported client issuer does not match the worker certificate (remote CN='$remote_cn')"
  fi
else
  warn "Worker not reachable over passwordless SSH from here; skipped the remote comparison."
fi

summary
