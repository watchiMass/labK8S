#!/usr/bin/env bash
# Installe Cilium (NetworkPolicy) et attend qu'il soit réellement prêt.
#
# Sur un cluster fraîchement initialisé, les nœuds sont NotReady tant qu'aucun
# CNI n'est configuré. Certaines versions du chart Cilium ne tolèrent pas tous
# les taints de bootstrap : on élargit les tolerations des DaemonSets Cilium
# pour qu'ils puissent démarrer sur les nœuds NotReady.
set -euo pipefail

export KUBECONFIG=/etc/kubernetes/admin.conf
ARCH="$(dpkg --print-architecture)"

if ! command -v cilium >/dev/null 2>&1; then
  CILIUM_CLI_VERSION="$(curl -fsSL https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)"
  cd /tmp
  curl -fsSL --remote-name-all \
    "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz"{,.sha256sum}
  sha256sum --check "cilium-linux-${ARCH}.tar.gz.sha256sum"
  tar xzf "cilium-linux-${ARCH}.tar.gz" -C /usr/local/bin
  rm -f cilium-linux-*
  cd - >/dev/null
fi

if ! kubectl -n kube-system get daemonset cilium >/dev/null 2>&1; then
  cilium install --set ipam.mode=kubernetes
fi

# Tolérer tous les taints sur les DaemonSets Cilium : indispensable pour que
# l'agent démarre avant que les nœuds ne soient Ready (bootstrap CNI).
for ds in cilium cilium-envoy; do
  if kubectl -n kube-system get daemonset "${ds}" >/dev/null 2>&1; then
    kubectl -n kube-system patch daemonset "${ds}" --type=json \
      -p '[{"op":"add","path":"/spec/template/spec/tolerations","value":[{"operator":"Exists"}]}]' \
      >/dev/null 2>&1 || true
  fi
done

dump_diagnostics() {
  echo "===== Diagnostic Cilium =====" >&2
  kubectl get nodes -o wide >&2 || true
  kubectl -n kube-system get pods -o wide >&2 || true
  kubectl -n kube-system describe pod -l k8s-app=cilium 2>/dev/null | tail -n 80 >&2 || true
  kubectl -n kube-system describe pod -l k8s-app=cilium-envoy 2>/dev/null | tail -n 40 >&2 || true
  kubectl -n kube-system get pods -l component=kube-scheduler -o wide >&2 || true
  kubectl -n kube-system logs -l component=kube-scheduler --tail=30 >&2 || true
  echo "============================" >&2
}

if ! kubectl -n kube-system rollout status daemonset/cilium --timeout=10m; then
  dump_diagnostics
  exit 1
fi

if kubectl -n kube-system get daemonset cilium-envoy >/dev/null 2>&1; then
  if ! kubectl -n kube-system rollout status daemonset/cilium-envoy --timeout=10m; then
    dump_diagnostics
    exit 1
  fi
fi

cilium status --wait
