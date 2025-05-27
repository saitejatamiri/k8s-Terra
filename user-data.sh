#!/bin/bash

set -eux

# Update and install dependencies
apt update -y
apt upgrade -y
apt install -y curl apt-transport-https ca-certificates software-properties-common git

# Docker
apt install -y docker.io
systemctl enable docker
usermod -aG docker ubuntu

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube

# Start Minikube with none driver
minikube start --driver=none

