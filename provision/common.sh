#!/usr/bin/env bash
# Prérequis communs aux 3 nœuds : OS, containerd, kubeadm/kubelet/kubectl,
# outils de diagnostic et préparation du disque.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

: "${NODE_IP:?NODE_IP is required}"
: "${K8S_VERSION:?K8S_VERSION is required}"

# Shell interactif confortable pour les connexions vagrant ssh.
usermod --shell /bin/bash vagrant 2>/dev/null || true

# --- Disque : agrandir la partition racine si le volume libvirt a été agrandi ---
apt-get update
apt-get install -y cloud-guest-utils
ROOT_SRC="$(findmnt -n -o SOURCE / || true)"
if [[ "$ROOT_SRC" =~ ^/dev/vda([0-9]+)$ ]]; then
  growpart /dev/vda "${BASH_REMATCH[1]}" >/dev/null 2>&1 || true
  resize2fs "$ROOT_SRC" >/dev/null 2>&1 || true
fi

# --- kubelet refuse de démarrer avec du swap ---
swapoff -a
sed -i '/[[:space:]]swap[[:space:]]/ s/^/#/' /etc/fstab

# --- Modules et sysctl réseau ---
cat >/etc/modules-load.d/k8s.conf <<'EOF'
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter
cat >/etc/sysctl.d/k8s.conf <<'EOF'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null

# --- containerd avec cgroups systemd ---
apt-get install -y containerd ca-certificates curl gpg
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# --- Dépôt Kubernetes et paquets ---
install -d -m 0755 /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" \
  | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# --- Outils utiles pour les labs et l'examen ---
apt-get install -y \
  git jq vim nano tmux less tree htop openssl \
  bash-completion dnsutils net-tools tcpdump \
  cri-tools

cat >/etc/crictl.yaml <<'EOF'
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

# --- etcd/etcdctl/etcdutl (B04, D15) ---
if ! command -v etcdctl >/dev/null 2>&1 || ! command -v etcdutl >/dev/null 2>&1; then
  ETCD_VERSION="v3.5.17"
  ARCH="$(dpkg --print-architecture)"
  TMP_ETCD="$(mktemp -d)"
  if curl -fsSL \
    "https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-${ARCH}.tar.gz" \
    -o "${TMP_ETCD}/etcd.tgz"; then
    tar -xzf "${TMP_ETCD}/etcd.tgz" -C "${TMP_ETCD}"
    install -m 0755 "${TMP_ETCD}/etcd-${ETCD_VERSION}-linux-${ARCH}/etcd" /usr/local/bin/etcd
    install -m 0755 "${TMP_ETCD}/etcd-${ETCD_VERSION}-linux-${ARCH}/etcdctl" /usr/local/bin/etcdctl
    install -m 0755 "${TMP_ETCD}/etcd-${ETCD_VERSION}-linux-${ARCH}/etcdutl" /usr/local/bin/etcdutl
  else
    echo "[!] Téléchargement des outils etcd impossible ; les labs les téléchargeront si besoin." >&2
  fi
  rm -rf "${TMP_ETCD}"
fi

# --- helm (A13) ---
if ! command -v helm >/dev/null 2>&1; then
  if ! curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash; then
    echo "[!] Installation de helm impossible ; A13 en aura besoin." >&2
  fi
fi

# --- Le nœud annonce son IP privée (eth1), pas l'IP NAT Vagrant ---
cat >/etc/default/kubelet <<EOF
KUBELET_EXTRA_ARGS=--node-ip=${NODE_IP}
EOF

systemctl enable --now kubelet
