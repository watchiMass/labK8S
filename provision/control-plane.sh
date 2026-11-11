#!/usr/bin/env bash
# Initialise le control plane une seule fois. Relancer ce provisioner ne
# réinitialise pas le cluster.
set -euo pipefail

if [[ ! -f /etc/kubernetes/admin.conf ]]; then
  kubeadm init \
    --apiserver-advertise-address "${NODE_IP}" \
    --pod-network-cidr 10.244.0.0/16 \
    --token "${TOKEN}" --token-ttl 0
else
  echo "Control plane déjà initialisé, kubeadm init ignoré."
fi
