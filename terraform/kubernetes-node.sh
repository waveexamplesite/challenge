#!/bin/bash

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update
apt-get -y upgrade

apt-get install -y docker.io
apt-get install -y kubelet kubeadm kubectl kubernetes-cni

until kubeadm join --token=${kubernetes-token} ${masterIP}; do
    sleep 15;
done
