#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

need_kubectl
need_cmd python3 "Install python3 (needed to patch the CoreDNS ConfigMap)."
QWORK="$CKA_WORKROOT/series-b/q09-coredns-repair"
ensure_workdir "$QWORK"

DNS_DEPLOY=$(kubectl -n kube-system get deployment -l k8s-app=kube-dns \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
[[ -n "$DNS_DEPLOY" ]] || die "No kube-dns/CoreDNS Deployment found in kube-system."

DNS_CM=$(kubectl -n kube-system get deployment "$DNS_DEPLOY" \
  -o jsonpath='{.spec.template.spec.volumes[?(@.configMap)].configMap.name}' 2>/dev/null | awk '{print $1}')
[[ -n "$DNS_CM" ]] || DNS_CM="$DNS_DEPLOY"
kubectl -n kube-system get configmap "$DNS_CM" >/dev/null 2>&1 \
  || die "Could not find the CoreDNS ConfigMap (tried '$DNS_CM')."

BACKUP="$QWORK/Corefile.orig"
PATCH="$QWORK/coredns-patch.json"

restore_corefile() {
  local core="$1"
  python3 -c 'import json,sys; print(json.dumps({"data":{"Corefile": sys.argv[1]}}))' "$core" >"$PATCH"
  kubectl -n kube-system patch configmap "$DNS_CM" --type merge --patch-file "$PATCH" >/dev/null
}

if [[ -s "$BACKUP" ]]; then
  restore_corefile "$(cat "$BACKUP")"
fi

kubectl -n kube-system get configmap "$DNS_CM" -o jsonpath='{.data.Corefile}' >"$BACKUP"
grep -q '\.:53' "$BACKUP" || die "The Corefile does not contain '.:53'; unsupported CoreDNS config."

NEW_CORE=$(sed '0,/\.:53/s//.:5353/' "$BACKUP")
python3 -c 'import json,sys; print(json.dumps({"data":{"Corefile": sys.argv[1]}}))' "$NEW_CORE" >"$PATCH"
kubectl -n kube-system patch configmap "$DNS_CM" --type merge --patch-file "$PATCH" >/dev/null
rm -f "$PATCH"

kubectl -n kube-system rollout restart deployment/"$DNS_DEPLOY" >/dev/null
kubectl -n kube-system rollout status deployment/"$DNS_DEPLOY" --timeout=180s >/dev/null
kubectl delete pod dns-probe -n default --ignore-not-found >/dev/null 2>&1 || true

info "DNS has been broken as intended. Deployment: $DNS_DEPLOY / ConfigMap: $DNS_CM"
