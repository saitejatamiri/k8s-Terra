provider "aws" {
  region = "us-east-1"
}

resource "aws_key_pair" "deployer" {
  key_name   = "minikube-key"
  public_key = file("~/.ssh/id_rsa.pub") # adjust if needed
}

resource "aws_security_group" "minikube_sg" {
  name        = "minikube-sg"
  description = "Allow SSH and NodePort"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # NodePort range
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "minikube_ec2" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 24.04 LTS (check for latest)
  instance_type = "t2.medium"
  key_name      = aws_key_pair.deployer.key_name
  security_groups = [aws_security_group.minikube_sg.name]

  user_data = file("user-data.sh")

  tags = {
    Name = "MinikubeEC2"
  }
}
