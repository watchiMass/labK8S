#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_root_or_sudo
QWORK="$CKA_WORKROOT/series-d/q15-etcd-isolated-restore"
ensure_workdir "$QWORK"
ensure_etcd_tools

CACERT=/etc/kubernetes/pki/etcd/ca.crt
CERT=/etc/kubernetes/pki/etcd/server.crt
KEY=/etc/kubernetes/pki/etcd/server.key
$SUDO test -r "$CACERT" || die "$CACERT not found; kubeadm etcd certificates are required."
$SUDO test -r "$CERT"  || die "$CERT not found."
$SUDO test -r "$KEY"   || die "$KEY not found."

port_open() {
  (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}
if port_open 12379 || port_open 12380; then
  die "Ports 12379/12380 are already in use. Run cleanup.sh from a previous attempt first."
fi

kubectl create namespace d15-etcd --dry-run=client -o yaml | kubectl apply -f - >/dev/null
rm -rf "$QWORK/etcd-restore" "$QWORK/source-snapshot.db" \
       "$QWORK/etcd.pid" "$QWORK/etcd.log" "$QWORK/namespaces.txt" "$QWORK/tools.txt"

$SUDO env ETCDCTL_API=3 "$ETCDCTL" \
  --endpoints=https://127.0.0.1:2379 \
  --cacert="$CACERT" --cert="$CERT" --key="$KEY" \
  snapshot save "$QWORK/source-snapshot.db" >/dev/null \
  || die "Could not create the source snapshot from the live etcd."
$SUDO chown "$(id -u):$(id -g)" "$QWORK/source-snapshot.db" 2>/dev/null || true

printf 'ETCD=%s\nETCDCTL=%s\nETCDUTL=%s\n' "$ETCD" "$ETCDCTL" "$ETCDUTL" >"$QWORK/tools.txt"

info "Snapshot ready: $QWORK/source-snapshot.db"
info "Binary paths written to $QWORK/tools.txt"
