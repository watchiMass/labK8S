#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$CKA_WORKROOT/series-d/q05-coredns-rewrite"
BACKUP="$QWORK/Corefile.orig"
PATCH="$QWORK/coredns-patch.json"

if [[ -s "$BACKUP" ]] && kubectl cluster-info >/dev/null 2>&1; then
  need_cmd python3 "python3 is required to restore the CoreDNS ConfigMap."
  DNS_DEPLOY=$(cat "$QWORK/dns-deploy.txt" 2>/dev/null || true)
  DNS_CM=$(cat "$QWORK/dns-cm.txt" 2>/dev/null || true)
  if [[ -n "$DNS_DEPLOY" && -n "$DNS_CM" ]]; then
    core=$(cat "$BACKUP" 2>/dev/null || true)
    if [[ -n "$core" ]]; then
      python3 -c 'import json,sys; print(json.dumps({"data":{"Corefile": sys.argv[1]}}))' \
        "$core" >"$PATCH"
      kubectl -n kube-system patch configmap "$DNS_CM" --type merge --patch-file "$PATCH" >/dev/null 2>&1 || true
      kubectl -n kube-system rollout restart deployment/"$DNS_DEPLOY" >/dev/null 2>&1 || true
      kubectl -n kube-system rollout status deployment/"$DNS_DEPLOY" --timeout=120s >/dev/null 2>&1 || true
    fi
  fi
  kubectl delete namespace d05-dns --ignore-not-found >/dev/null 2>&1 || true
fi

rm -f "$BACKUP" "$PATCH" "$QWORK/dns-deploy.txt" "$QWORK/dns-cm.txt"
info "Restored the original Corefile and removed namespace d05-dns."
