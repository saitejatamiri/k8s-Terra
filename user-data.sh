#!/bin/bash
set +xe

# Update system and install dependencies
sudo yum update -y
sudo yum install -y git conntrack

# Install Docker
sudo yum install -y docker
sudo amazon-linux-extras enable docker
sudo systemctl start docker
sudo systemctl enable docker

sudo usermod -aG docker ec2-user

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
sudo chown ec2-user:ec2-user /usr/local/bin/kubectl

# Install minikube
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube
sudo mv minikube /usr/local/bin/
sudo chown ec2-user:ec2-user /usr/local/bin/minikube

# Ensure PATH for ec2-user includes /usr/local/bin
if ! grep -q '/usr/local/bin' /home/ec2-user/.bash_profile; then
  echo 'export PATH=$PATH:/usr/local/bin' >> /home/ec2-user/.bash_profile
  sudo chown ec2-user:ec2-user /home/ec2-user/.bash_profile
fi

# Create systemd service file for minikube
sudo tee /etc/systemd/system/minikube.service > /dev/null <<EOF
[Unit]
Description=Minikube Kubernetes
After=docker.service
Requires=docker.service

[Service]
User=ec2-user
Group=ec2-user
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/local/bin/minikube start --force
EOF

# Reload systemd, enable and start minikube service
sudo systemctl daemon-reload
sudo systemctl enable minikube
sudo systemctl start minikube

docker run  --cpus=1 --memory=2g \
  -e DELEGATE_NAME=docker-delegate-a1a \
  -e NEXT_GEN="true" \
  -e DELEGATE_TYPE="DOCKER" \
  -e ACCOUNT_ID=ucHySz2jQKKWQweZdXyCog \
  -e DELEGATE_TOKEN=NTRhYTY0Mjg3NThkNjBiNjMzNzhjOGQyNjEwOTQyZjY= \
  -e DELEGATE_TAGS="" \
  -e MANAGER_HOST_AND_PORT=https://app.harness.io us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate:25.05.85903
