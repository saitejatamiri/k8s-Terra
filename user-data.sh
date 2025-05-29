#!/bin/bash
set -xe

# Update packages
yum update -y

# Install dependencies
yum install -y git curl wget conntrack

# Enable and install Docker
amazon-linux-extras enable docker
yum install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/
chown ec2-user:ec2-user /usr/local/bin/kubectl

# Install Minikube
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube
mv minikube /usr/local/bin/
chown ec2-user:ec2-user /usr/local/bin/minikube

# Fix PATH
echo 'export PATH=$PATH:/usr/local/bin' >> /home/ec2-user/.bash_profile
chown ec2-user:ec2-user /home/ec2-user/.bash_profile

# Create systemd service to auto-start Minikube as ec2-user
cat <<EOF > /etc/systemd/system/minikube-start.service
[Unit]
Description=Start Minikube
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
User=ec2-user
ExecStart=/usr/local/bin/minikube start --driver=none
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable the service to run on boot
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable minikube-start.service
