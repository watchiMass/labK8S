#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
QWORK="$CKA_WORKROOT/series-b/q04-etcd-snapshot-restore"
info "Validating etcd version, snapshot, status and restore..."

if [[ -s "$QWORK/etcd-version" ]] && grep -qi 'etcd Version' "$QWORK/etcd-version"; then
  pass "etcd-version contains the etcd binary version output"
else
  fail "etcd-version is missing or does not contain 'etcd Version'"
fi

if [[ -s "$QWORK/etcd-snapshot.db" ]]; then
  size=$(stat -c '%s' "$QWORK/etcd-snapshot.db" 2>/dev/null || echo 0)
  if [[ "$size" -gt 100000 ]]; then
    pass "snapshot file exists (${size} bytes)"
  else
    fail "snapshot file is suspiciously small (${size} bytes)"
  fi
else
  fail "etcd-snapshot.db is missing"
fi

ensure_etcd_tools

if [[ -s "$QWORK/etcd-snapshot.db" ]]; then
  if status=$("$ETCDUTL" snapshot status "$QWORK/etcd-snapshot.db" 2>/dev/null); then
    pass "etcdutl can read the snapshot"
    if grep -qi 'revision' <<<"$status"; then
      pass "snapshot status contains a revision"
    else
      warn "snapshot status output did not mention revision: $status"
    fi
  else
    fail "etcdutl snapshot status failed on the snapshot"
  fi
fi

if [[ -s "$QWORK/etcd-snapshot-status" ]]; then
  if grep -qi 'revision' "$QWORK/etcd-snapshot-status"; then
    pass "etcd-snapshot-status contains the status output"
  else
    fail "etcd-snapshot-status does not look like etcdutl output"
  fi
else
  fail "etcd-snapshot-status is missing"
fi

if [[ -s "$QWORK/etcd-restore/member/snap/db" ]]; then
  pass "restored data directory contains member/snap/db"
else
  fail "restored data directory is missing or incomplete (expected member/snap/db)"
fi

summary
