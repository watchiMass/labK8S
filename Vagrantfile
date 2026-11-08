# -*- mode: ruby -*-
# Cluster Kubernetes (kubeadm) : 1 control plane + 2 workers
# Vagrant + libvirt/KVM, Ubuntu 24.04, containerd, Cilium

K8S_VERSION = "v1.36"                     # branche pkgs.k8s.io (v1.37 est la dernière sortie)
CP_IP       = "192.168.56.10"
JOIN_TOKEN  = "abcdef.0123456789abcdef"   # token fixe : OK pour un lab local uniquement

NODES = [
  { name: "cp1", ip: CP_IP,           cpus: 2, memory: 3072, role: "cp" },
  { name: "w1",  ip: "192.168.56.11", cpus: 2, memory: 3072, role: "worker" },
  { name: "w2",  ip: "192.168.56.12", cpus: 2, memory: 3072, role: "worker" },
]

# --- Commun aux 3 nœuds : prérequis, containerd, kubeadm/kubelet/kubectl ---
COMMON = <<~'SHELL'
  set -euxo pipefail
  export DEBIAN_FRONTEND=noninteractive

  # kubelet refuse de démarrer avec du swap
  swapoff -a
  sed -i '/ swap / s/^/#/' /etc/fstab

  # modules et sysctl réseau
  cat >/etc/modules-load.d/k8s.conf <<EOF
  overlay
  br_netfilter
  EOF
  modprobe overlay
  modprobe br_netfilter
  cat >/etc/sysctl.d/k8s.conf <<EOF
  net.bridge.bridge-nf-call-iptables  = 1
  net.bridge.bridge-nf-call-ip6tables = 1
  net.ipv4.ip_forward                 = 1
  EOF
  sysctl --system

  # containerd avec cgroups systemd
  apt-get update
  apt-get install -y containerd ca-certificates curl gpg
  mkdir -p /etc/containerd
  containerd config default > /etc/containerd/config.toml
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  systemctl restart containerd
  systemctl enable containerd

  # kubeadm, kubelet, kubectl
  mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" \
    | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" \
    > /etc/apt/sources.list.d/kubernetes.list
  apt-get update
  apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl

  # le nœud doit annoncer son IP privée (eth1), pas celle du NAT Vagrant (eth0)
  echo "KUBELET_EXTRA_ARGS=--node-ip=${NODE_IP}" > /etc/default/kubelet
  systemctl enable --now kubelet
SHELL

# --- Control plane : kubeadm init + CNI Cilium ---
CONTROL_PLANE = <<~'SHELL'
  set -euxo pipefail

  kubeadm init \
    --apiserver-advertise-address "${NODE_IP}" \
    --pod-network-cidr 10.244.0.0/16 \
    --token "${TOKEN}" --token-ttl 0

  mkdir -p /home/vagrant/.kube
  cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
  chown -R vagrant:vagrant /home/vagrant/.kube

  export KUBECONFIG=/etc/kubernetes/admin.conf
  CLI_ARCH=amd64
  CILIUM_CLI_VERSION=$(curl -fsSL https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
  curl -fsSL --remote-name-all \
    "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"{,.sha256sum}
  sha256sum --check "cilium-linux-${CLI_ARCH}.tar.gz.sha256sum"
  tar xzf "cilium-linux-${CLI_ARCH}.tar.gz" -C /usr/local/bin
  rm -f cilium-linux-*

  cilium install --set ipam.mode=kubernetes
  cilium status --wait
SHELL

# --- Workers : kubeadm join ---
WORKER = <<~'SHELL'
  set -euxo pipefail
  kubeadm join "${CP_IP}:6443" \
    --token "${TOKEN}" \
    --discovery-token-unsafe-skip-ca-verification
SHELL

Vagrant.configure("2") do |config|
  config.vm.box = "cloud-image/ubuntu-24.04"
  config.vm.box_check_update = false
  config.vm.synced_folder ".", "/vagrant", disabled: true

  NODES.each do |n|
    config.vm.define n[:name] do |node|
      node.vm.hostname = n[:name]
      node.vm.network "private_network", ip: n[:ip]

      node.vm.provider "libvirt" do |lv|
        lv.cpus   = n[:cpus]
        lv.memory = n[:memory]
      end

      env = {
        "NODE_IP"     => n[:ip],
        "CP_IP"       => CP_IP,
        "K8S_VERSION" => K8S_VERSION,
        "TOKEN"       => JOIN_TOKEN,
      }
      node.vm.provision "common",  type: "shell", inline: COMMON, env: env
      node.vm.provision "kubeadm", type: "shell", env: env,
                        inline: (n[:role] == "cp" ? CONTROL_PLANE : WORKER)
    end
  end
end
