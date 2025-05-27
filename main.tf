provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "minikube_sg" {
  name        = "minikube-sg"
  description = "Allow NodePort and web access"

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow NodePort
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Optional for HTTP apps
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Optional for HTTPS apps
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "minikube_ec2" {
  ami                    = "ami-0e58b56aa4d64231b" # Ubuntu 24.04 LTS (verify latest)
  instance_type          = "t2.medium"
  key_name               = "Teja-1"
  security_groups        = [sg-01e44a8c425a86e45]
  associate_public_ip_address = true

  user_data              = file("userdata.sh")

  tags = {
    Name = "MinikubeEC2"
  }
}
