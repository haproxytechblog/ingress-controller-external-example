#!/bin/bash

# Install HAProxy
add-apt-repository -y ppa:vbernat/haproxy-2.4
apt update
apt install -y haproxy
systemctl stop haproxy
systemctl disable haproxy

# Allow the haproxy binary to bind to ports 80 and 443:
setcap cap_net_bind_service=+ep /usr/sbin/haproxy

# Install the HAProxy Kubernetes Ingress Controller
wget https://github.com/haproxytech/kubernetes-ingress/releases/download/v1.6.2/haproxy-ingress-controller_1.6.2_Linux_x86_64.tar.gz 1> /dev/null 2> /dev/null
mkdir ingress-controller
tar -xzvf haproxy-ingress-controller_1.6.2_Linux_x86_64.tar.gz -C ./ingress-controller
cp ./ingress-controller/haproxy-ingress-controller /usr/local/bin/

cp /vagrant/haproxy-ingress.service /lib/systemd/system/
systemctl enable haproxy-ingress
systemctl start haproxy-ingress

# Copy kube config to this server
mkdir -p /root/.kube
cp /vagrant/admin.conf /root/.kube/config
chown -R root:root /root/.kube

# Install Bird
add-apt-repository -y ppa:cz.nic-labs/bird
apt update
apt install bird

# Copy over bird.conf
sudo cp /vagrant/bird.conf /etc/bird/
sudo systemctl enable bird
sudo systemctl restart bird
