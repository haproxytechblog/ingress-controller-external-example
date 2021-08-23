#!/bin/bash

NODE_IP=$1

# Disable swap, as required by kubelet
swapoff -a

# Install Docker
apt update
DEBIAN_FRONTEND=noninteractive apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
DEBIAN_FRONTEND=noninteractive apt install -y docker-ce

# Change Docker cgroup driver to systemd
cp /vagrant/daemon.json /etc/docker/
systemctl restart docker

# Install kubeadm
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Configure the worker node
kubeadm join --token db1e3e.5044869ec5bc2393 192.168.50.22:6443 --discovery-token-unsafe-skip-ca-verification

mkdir -p /home/vagrant/.kube
cp /vagrant/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

# Set the --node-ip argument for kubelet
touch /etc/default/kubelet
echo "KUBELET_EXTRA_ARGS=--node-ip=$NODE_IP" > /etc/default/kubelet
systemctl daemon-reload
systemctl restart kubelet
