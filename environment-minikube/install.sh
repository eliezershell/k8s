#!/bin/bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
sudo dpkg -i minikube_latest_amd64.deb

sudo apt update -y
git clone https://github.com/eliezershell/docker.git
chmod +x ./docker/instalador_docker.sh
./docker/instalador_docker.sh

minikube start --driver=docker
sudo snap install kubectl --classic
