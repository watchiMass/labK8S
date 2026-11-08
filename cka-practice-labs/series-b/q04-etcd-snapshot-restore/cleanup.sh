#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$CKA_WORKROOT/series-b/q04-etcd-snapshot-restore"
rm -rf "$QWORK/etcd-version" "$QWORK/etcd-snapshot.db" \
       "$QWORK/etcd-snapshot-status" "$QWORK/etcd-restore"
info "Removed the etcd exercise artifacts (the downloaded tools are kept)."
