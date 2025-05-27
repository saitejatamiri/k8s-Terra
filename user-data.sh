#!/bin/bash
set -xe

yum update -y

# install git
yum install git -y

# Install Docker on Amazon Linux 2
amazon-linux-extras enable docker
yum install -y docker

systemctl start docker
systemctl enable docker

usermod -aG docker ec2-user

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/
chown ec2-user:ec2-user /usr/local/bin/kubectl

# Install conntrack (required for minikube)
yum install -y conntrack

# Install minikube
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube
mv minikube /usr/local/bin/
chown ec2-user:ec2-user /usr/local/bin/minikube
# Start minikube as ec2-user using none driver (bare metal)
sudo -i -u ec2-user bash -c 'minikube start --driver=none'

# Ensure /usr/local/bin is in ec2-user's PATH
grep -qxF 'export PATH=$PATH:/usr/local/bin' /home/ec2-user/.bash_profile || echo 'export PATH=$PATH:/usr/local/bin' >> /home/ec2-user/.bash_profile
chown ec2-user:ec2-user /home/ec2-user/.bash_profile
