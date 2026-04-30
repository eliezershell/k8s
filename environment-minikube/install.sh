#!/bin/bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
sudo dpkg -i minikube_latest_amd64.deb

sudo apt update -y
git clone https://github.com/eliezershell/docker.git
chmod +x ./docker/instalador_docker.sh
./docker/instalador_docker.sh

exit 0

minikube start --driver=docker --nodes 2
minikube addons enable ingress
sudo snap install kubectl --classic

# roda na EC2, redireciona porta 80 para o IP do minikube
MINIKUBE_IP=$(minikube ip)

sudo sysctl -w net.ipv4.ip_forward=1

sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination $MINIKUBE_IP:80
sudo iptables -A FORWARD -p tcp -d $MINIKUBE_IP --dport 80 -j ACCEPT
