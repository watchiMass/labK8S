#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$SCRIPT_DIR"
need_root_or_sudo

PID=$(head -n1 "$QWORK/etcd.pid" 2>/dev/null | tr -d '[:space:]' || true)
if [[ "$PID" =~ ^[0-9]+$ ]] && $SUDO test -d "/proc/$PID"; then
  cmdline=$($SUDO cat "/proc/$PID/cmdline" 2>/dev/null | tr '\0' ' ' || true)
  if [[ "$cmdline" == *etcd* && "$cmdline" == *etcd-restore* ]]; then
    $SUDO kill "$PID" >/dev/null 2>&1 || true
    for _ in $(seq 1 10); do
      $SUDO test -d "/proc/$PID" || break
      sleep 1
    done
    if $SUDO test -d "/proc/$PID"; then
      $SUDO kill -9 "$PID" >/dev/null 2>&1 || true
    fi
    info "Stopped temporary etcd process $PID."
  else
    warn "PID $PID is not the expected etcd process; not killing it."
  fi
fi

if kubectl cluster-info >/dev/null 2>&1; then
  kubectl delete namespace d15-etcd --ignore-not-found >/dev/null 2>&1 || true
fi
rm -rf "$QWORK/etcd-restore" "$QWORK/source-snapshot.db" \
       "$QWORK/etcd.pid" "$QWORK/etcd.log" "$QWORK/namespaces.txt" "$QWORK/tools.txt"
info "Cleaned up the temporary etcd and exercise files (downloaded tools are kept)."
