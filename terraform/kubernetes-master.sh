#!/bin/bash

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update
apt-get -y upgrade

apt-get install -y docker.io
apt-get install -y kubelet kubeadm kubectl kubernetes-cni

kubeadm init --token=${kubernetes-token} --api-external-dns-names=kubernetes-api.waveexample.site
kubectl apply -f https://git.io/weave-kube