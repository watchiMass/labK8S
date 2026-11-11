# -*- mode: ruby -*-
# Cluster Kubernetes (kubeadm) : 1 control plane + 2 workers, avec un desktop
# XFCE qui reproduit l'environnement d'examen CKA (ExamUI).
# Vagrant + libvirt/KVM, Ubuntu 24.04, containerd, Cilium.

require "fileutils"

K8S_VERSION      = ENV.fetch("CKA_K8S_VERSION", "v1.36")
CP_IP            = "192.168.56.10"
JOIN_TOKEN       = "abcdef.0123456789abcdef" # token fixe : lab local uniquement
DESKTOP_PASSWORD = ENV.fetch("CKA_DESKTOP_PASSWORD", "candidate")
VNC_PASSWORD     = ENV.fetch("CKA_VNC_PASSWORD", "cka-lab1")[0, 8]

NODES = [
  { vm: "cp1", host: "base",   ip: CP_IP,           cpus: 4, memory: 6144, disk: 40, role: "cp" },
  { vm: "w1",  host: "node01", ip: "192.168.56.11", cpus: 2, memory: 2048, disk: 20, role: "worker" },
  { vm: "w2",  host: "node02", ip: "192.168.56.12", cpus: 2, memory: 2048, disk: 20, role: "worker" },
]

# Clé SSH de labo : hôte -> base, et base -> workers.
# Générée une seule fois sur l'hôte et ignorée par git.
LAB_KEY_DIR = File.join(File.dirname(File.expand_path(__FILE__)), "provision")
LAB_KEY     = File.join(LAB_KEY_DIR, ".lab_key")
LAB_KEY_PUB = "#{LAB_KEY}.pub"

FileUtils.mkdir_p(LAB_KEY_DIR)
unless File.exist?(LAB_KEY)
  FileUtils.rm_f(LAB_KEY_PUB)
  ok = system("ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-C", "cka-lab", "-f", LAB_KEY)
  abort("Impossible de générer la clé SSH de labo dans #{LAB_KEY_DIR}") unless ok
end
unless File.exist?(LAB_KEY_PUB)
  ok = system("ssh-keygen", "-y", "-f", LAB_KEY, out: LAB_KEY_PUB)
  abort("Impossible de régénérer la clé publique #{LAB_KEY_PUB}") unless ok
end

Vagrant.configure("2") do |config|
  config.vm.box = "cloud-image/ubuntu-24.04"
  config.vm.box_check_update = false
  config.vm.synced_folder ".", "/vagrant", disabled: true

  NODES.each do |n|
    config.vm.define n[:vm] do |node|
      node.vm.hostname = n[:host]
      node.vm.network "private_network", ip: n[:ip]

      node.vm.provider "libvirt" do |lv|
        lv.cpus   = n[:cpus]
        lv.memory = n[:memory]
        lv.machine_virtual_size = n[:disk]
      end

      env = {
        "NODE_IP"       => n[:ip],
        "NODE_HOSTNAME" => n[:host],
        "CP_IP"         => CP_IP,
        "K8S_VERSION"   => K8S_VERSION,
        "TOKEN"         => JOIN_TOKEN,
        "CKA_DESKTOP_PASSWORD" => DESKTOP_PASSWORD,
        "CKA_VNC_PASSWORD"     => VNC_PASSWORD,
      }

      node.vm.provision "common", type: "shell", path: "provision/common.sh", env: env

      node.vm.provision "lab-key", type: "file",
                        source: "provision/.lab_key.pub",
                        destination: "/tmp/cka-lab-key.pub"
      if n[:role] == "cp"
        node.vm.provision "lab-key-private", type: "file",
                          source: "provision/.lab_key",
                          destination: "/tmp/cka-lab-key"
      end

      node.vm.provision "candidate", type: "shell", path: "provision/candidate.sh", env: env

      node.vm.provision "kubeadm", type: "shell",
                        path: (n[:role] == "cp" ? "provision/control-plane.sh" : "provision/worker.sh"),
                        env: env

      if n[:role] == "cp"
        node.vm.provision "kubeconfig", type: "shell", path: "provision/kubeconfig.sh", env: env
        node.vm.provision "cni", type: "shell", path: "provision/cni.sh", env: env

        node.vm.provision "desktop-assets", type: "file",
                          source: "provision/assets",
                          destination: "/tmp/cka-assets"
        node.vm.provision "desktop", type: "shell", path: "provision/desktop.sh", env: env
        node.vm.provision "desktop-config", type: "shell", path: "provision/desktop-config.sh", env: env

        node.vm.provision "exam-console-files", type: "file",
                          source: "provision/exam-console",
                          destination: "/tmp/cka-exam-console"
        node.vm.provision "exam-console", type: "shell", path: "provision/exam-console.sh", env: env

        node.vm.provision "labs-files", type: "file",
                          source: "cka-practice-labs",
                          destination: "/tmp/cka-practice-labs"
        node.vm.provision "labs", type: "shell", path: "provision/labs.sh", env: env
      end
    end
  end
end
