#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$SCRIPT_DIR"
REPORT="$QWORK/node-report.txt"
info "Validating node debug report..."

WORKER=$(cat "$QWORK/node.txt" 2>/dev/null || true)
[[ -n "$WORKER" ]] || fail "node.txt is missing; re-run setup.sh"

if [[ -s "$REPORT" ]]; then
  pass "node-report.txt exists"
else
  fail "node-report.txt is missing"
  summary
fi

pretty=$(grep -E '^PRETTY_NAME=' "$REPORT" | head -n1 | sed -E 's/^PRETTY_NAME=//; s/^"//; s/"$//' || true)
kernel=$(grep -E '^KERNEL=' "$REPORT" | head -n1 | sed -E 's/^KERNEL=//' || true)

if [[ -n "$pretty" ]]; then
  pass "PRETTY_NAME is present ($pretty)"
else
  fail "PRETTY_NAME is empty or missing"
fi

if [[ "$kernel" =~ [0-9]+\.[0-9]+ ]]; then
  pass "KERNEL looks like a kernel release ($kernel)"
else
  fail "KERNEL is missing or invalid (got '$kernel')"
fi

if [[ -n "$WORKER" ]] && ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
  "$WORKER" true >/dev/null 2>&1; then
  remote_pretty=$(ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
    "$WORKER" "grep '^PRETTY_NAME=' /etc/os-release" 2>/dev/null \
    | sed -E 's/^PRETTY_NAME=//; s/^"//; s/"$//' || true)
  remote_kernel=$(ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
    "$WORKER" "uname -r" 2>/dev/null | tr -d '\r\n' || true)
  if [[ -n "$remote_pretty" && "$pretty" == "$remote_pretty" ]]; then
    pass "PRETTY_NAME matches the worker's /etc/os-release"
  else
    fail "PRETTY_NAME does not match the worker (remote '$remote_pretty')"
  fi
  if [[ -n "$remote_kernel" && "$kernel" == "$remote_kernel" ]]; then
    pass "KERNEL matches the worker's uname -r"
  else
    fail "KERNEL does not match the worker (remote '$remote_kernel')"
  fi
else
  warn "Worker not reachable over passwordless SSH; skipped the remote comparison."
fi

summary
