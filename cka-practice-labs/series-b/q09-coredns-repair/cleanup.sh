#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

QWORK="$CKA_WORKROOT/series-b/q09-coredns-repair"
BACKUP="$QWORK/Corefile.orig"
PATCH="$QWORK/coredns-patch.json"

if [[ -s "$BACKUP" ]] && kubectl cluster-info >/dev/null 2>&1; then
  DNS_DEPLOY=$(kubectl -n kube-system get deployment -l k8s-app=kube-dns \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  DNS_CM=$(kubectl -n kube-system get deployment "$DNS_DEPLOY" \
    -o jsonpath='{.spec.template.spec.volumes[?(@.configMap)].configMap.name}' 2>/dev/null | awk '{print $1}')
  [[ -n "$DNS_CM" ]] || DNS_CM="$DNS_DEPLOY"
  if [[ -n "$DNS_DEPLOY" && -n "$DNS_CM" ]]; then
    python3 -c 'import json,sys; print(json.dumps({"data":{"Corefile": sys.argv[1]}}))' "$(cat "$BACKUP")" >"$PATCH" 2>/dev/null || true
    kubectl -n kube-system patch configmap "$DNS_CM" --type merge --patch-file "$PATCH" >/dev/null 2>&1 || true
    kubectl -n kube-system rollout restart deployment/"$DNS_DEPLOY" >/dev/null 2>&1 || true
    kubectl -n kube-system rollout status deployment/"$DNS_DEPLOY" --timeout=120s >/dev/null 2>&1 || true
  fi
  kubectl delete pod dns-probe -n default --ignore-not-found >/dev/null 2>&1 || true
fi

rm -f "$BACKUP" "$PATCH" "$QWORK/Corefile.broken"
info "Restored the original Corefile and restarted CoreDNS."
