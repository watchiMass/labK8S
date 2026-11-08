#!/usr/bin/env bash
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_root_or_sudo
QWORK="$CKA_WORKROOT/series-d/q15-etcd-isolated-restore"
info "Validating isolated etcd restore..."
ensure_etcd_tools

if [[ -s "$QWORK/source-snapshot.db" ]]; then
  pass "source snapshot exists"
else
  fail "source snapshot is missing; re-run setup.sh"
  summary
fi

if [[ -s "$QWORK/etcd-restore/member/snap/db" ]]; then
  pass "restored data directory contains member/snap/db"
else
  fail "restored data directory is missing or incomplete"
fi

PID=$(head -n1 "$QWORK/etcd.pid" 2>/dev/null | tr -d '[:space:]' || true)
if [[ "$PID" =~ ^[0-9]+$ ]] && $SUDO kill -0 "$PID" 2>/dev/null; then
  cmdline=$($SUDO cat "/proc/$PID/cmdline" 2>/dev/null | tr '\0' ' ' || true)
  if [[ "$cmdline" == *etcd* && "$cmdline" == *etcd-restore* ]]; then
    pass "temporary etcd process $PID is running with the restored data directory"
  else
    fail "PID $PID is alive but is not the expected etcd process"
  fi
else
  fail "no running etcd process found from etcd.pid"
fi

healthy=0
for _ in $(seq 1 20); do
  if ETCDCTL_API=3 "$ETCDCTL" --endpoints=http://127.0.0.1:12379 endpoint health >/dev/null 2>&1; then
    healthy=1
    break
  fi
  sleep 2
done
if [[ "$healthy" == "1" ]]; then
  pass "restored etcd endpoint is healthy on http://127.0.0.1:12379"
else
  fail "restored etcd endpoint is not healthy"
  summary
fi

actual=$("$ETCDCTL" --endpoints=http://127.0.0.1:12379 get /registry/namespaces \
  --prefix --keys-only 2>/dev/null \
  | sed -e 's#^/registry/namespaces/##' | grep -v '^$' | sort -u || true)

if [[ -z "$actual" ]]; then
  fail "could not read namespace keys from the restored etcd"
else
  pass "restored etcd contains namespace keys"
fi

if grep -qx 'd15-etcd' <<<"$actual"; then
  pass "restored data contains the marker namespace d15-etcd"
else
  fail "restored data does not contain the marker namespace d15-etcd"
fi

if [[ -s "$QWORK/namespaces.txt" ]]; then
  pass "namespaces.txt exists"
  reported=$(sed -e 's#^/registry/namespaces/##' \
    -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$QWORK/namespaces.txt" \
    | grep -v '^$' | sort -u || true)
  if [[ "$reported" == "$actual" ]]; then
    pass "namespaces.txt matches the namespaces read from the restored etcd"
  else
    fail "namespaces.txt does not match the restored namespace set"
  fi
else
  fail "namespaces.txt is missing"
fi

summary
