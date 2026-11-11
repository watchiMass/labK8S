#!/usr/bin/env bash
# Rejoint le cluster une seule fois. Relancer ce provisioner ne casse rien.
set -euo pipefail

if [[ ! -f /etc/kubernetes/kubelet.conf ]]; then
  # Vagrant peut démarrer les 3 machines en parallèle : attendre l'API server
  # du control plane avant de tenter le join.
  echo "Attente du control plane ${CP_IP}:6443..."
  cp_ready=0
  for _ in $(seq 1 180); do
    if curl -ksf "https://${CP_IP}:6443/healthz" >/dev/null 2>&1; then
      cp_ready=1
      break
    fi
    sleep 5
  done
  if [[ "${cp_ready}" -ne 1 ]]; then
    echo "Control plane injoignable après 15 minutes." >&2
    exit 1
  fi

  # L'API peut être saine avant que le token bootstrap soit créé : réessayer.
  joined=0
  for _ in $(seq 1 60); do
    if kubeadm join "${CP_IP}:6443" \
      --token "${TOKEN}" \
      --discovery-token-unsafe-skip-ca-verification; then
      joined=1
      break
    fi
    sleep 10
  done
  if [[ "${joined}" -ne 1 ]]; then
    echo "kubeadm join a échoué après plusieurs tentatives." >&2
    exit 1
  fi
else
  echo "Ce worker est déjà joint au cluster, kubeadm join ignoré."
fi
