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

# Install kubeadm and kubectl
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Call kubeadm init to create first Kubernetes node
kubeadm init --token db1e3e.5044869ec5bc2393 --apiserver-advertise-address 192.168.50.22 --pod-network-cidr=172.16.0.0/16

# Copy the kube config file to home directories
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

cp /etc/kubernetes/admin.conf /vagrant

# Install Calico
kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
kubectl apply -f /vagrant/calico-installation.yaml

# Remove the taints on the master so that you can schedule pods on it
# kubectl taint nodes --all node-role.kubernetes.io/master-

# Install calicoctl
wget https://github.com/projectcalico/calicoctl/releases/download/v3.14.0/calicoctl 1> /dev/null 2> /dev/null
chmod +x calicoctl
mv calicoctl /usr/local/bin/
sudo mkdir /etc/calico
sudo cp /vagrant/calicoctl.cfg /etc/calico/

# Configure Calico for BGP peering
calicoctl apply -f /vagrant/calico-bgpconfiguration.yaml

# Create ConfigMap for ingress controller
kubectl create configmap haproxy-kubernetes-ingress

# Set the --node-ip argument for kubelet
touch /etc/default/kubelet
echo "KUBELET_EXTRA_ARGS=--node-ip=$NODE_IP" > /etc/default/kubelet
systemctl daemon-reload
systemctl restart kubelet
