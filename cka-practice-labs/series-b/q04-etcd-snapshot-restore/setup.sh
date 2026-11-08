#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_root_or_sudo
QWORK="$CKA_WORKROOT/series-b/q04-etcd-snapshot-restore"
ensure_workdir "$QWORK"
ensure_etcd_tools

CACERT=/etc/kubernetes/pki/etcd/ca.crt
CERT=/etc/kubernetes/pki/etcd/server.crt
KEY=/etc/kubernetes/pki/etcd/server.key
$SUDO test -r "$CACERT" || die "$CACERT not found; this question expects kubeadm etcd certificates."
$SUDO test -r "$CERT"  || die "$CERT not found."
$SUDO test -r "$KEY"   || die "$KEY not found."

rm -rf "$QWORK/etcd-version" "$QWORK/etcd-snapshot.db" \
       "$QWORK/etcd-snapshot-status" "$QWORK/etcd-restore"

$SUDO env ETCDCTL_API=3 "$ETCDCTL" \
  --endpoints=https://127.0.0.1:2379 \
  --cacert="$CACERT" --cert="$CERT" --key="$KEY" \
  endpoint health >/dev/null \
  || die "Cannot reach etcd on https://127.0.0.1:2379 with the kubeadm certs."

info "etcd is reachable. Work directory: $QWORK"
