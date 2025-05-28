provider "aws" {
  region = "eu-north-1"
}

resource "aws_security_group" "allow_ssh_http" {
  name        = "allow_ssh_http"
  description = "Allow SSH and HTTP inbound"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # allow SSH from anywhere (adjust in production)
  }

  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

resource "aws_instance" "minikube_ec2" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.medium"
  key_name                    = "Teja-2"
  security_groups        = [aws_security_group.allow_ssh_http.name]
  associate_public_ip_address = true

  user_data = file("user-data.sh")

  tags = {
    Name = "minikube-ec2-instance"
  }
}

output "instance_public_ip" {
  value = aws_instance.minikube_ec2.public_ip
}
