#!/usr/bin/env bash
# Rend le kubeconfig admin disponible à vagrant, candidate et root sur base.
set -euo pipefail

install -d -m 0700 -o vagrant -g vagrant /home/vagrant/.kube
install -m 0600 -o vagrant -g vagrant /etc/kubernetes/admin.conf /home/vagrant/.kube/config

install -d -m 0700 -o candidate -g candidate /home/candidate/.kube
install -m 0600 -o candidate -g candidate /etc/kubernetes/admin.conf /home/candidate/.kube/config

install -d -m 0700 /root/.kube
install -m 0600 /etc/kubernetes/admin.conf /root/.kube/config
