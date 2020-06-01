terraform {
  required_version = ">= 0.12.24"
}

provider "aws" {
  version = "~>2.59.0"
  region  = "us-west-2"
}

variable "prefix" {
  type    = string
  default = ""
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "public_subnet" {
  type    = string
  default = ""
}

variable "ssh_port" {
  type    = number
  default = 22222
}

######################################################################################################################################################################
# Get My IP Address
######################################################################################################################################################################
data "external" "ipify" {
  program = ["curl", "-s", "https://api.ipify.org?format=json"]
}

######################################################################################################################################################################
# Create Key
######################################################################################################################################################################
resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "generated_key" {
  key_name   = "${var.prefix}-bastion-key"
  public_key = tls_private_key.bastion.public_key_openssh
}
resource "local_file" "write-key" {
  content  = tls_private_key.bastion.private_key_pem
  filename = "${path.module}/${var.prefix}-bastion-key.pem"
}

######################################################################################################################################################################
# Security Group to attach to the Bastion Server - External SSH Traffic on an OBSCURE port - Allow traffic from My IP Address 
######################################################################################################################################################################
resource "aws_security_group" "bastion_security_group" {
  name        = "${var.prefix}_bastion_security_group"
  description = "Security Group for Bastion"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "TCP"
    cidr_blocks = ["${data.external.ipify.result.ip}/32"]
    description = "SSH Ingress"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

######################################################################################################################################################################
# BASTION - Create an EC2 Instance in the Public Subnet using the Amazon Linux 2 AMI 
######################################################################################################################################################################
data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon-linux-2.id
  instance_type = "t2.micro"
  tags = {
    Name = "${var.prefix}-Bastion"
  }
  subnet_id                   = var.public_subnet
  associate_public_ip_address = true
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [aws_security_group.bastion_security_group.id]
  user_data                   = <<-EOF
    #!/bin/bash
    sudo yum update -y && sudo yum upgrade -y
    sudo sed -i 's/#Port 22/Port ${var.ssh_port}/g' /etc/ssh/sshd_config
    sudo service sshd restart
    sudo yum install mysql -y 
  EOF
}

######################################################################################################################################################################
# Security Groups to allow access from the Bastion
######################################################################################################################################################################
resource "aws_security_group" "ssh_from_bastion" {
  name        = "${var.prefix}_SSH_FROM_BASTION"
  description = "SSH from Bastion"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["${aws_instance.bastion.private_ip}/32"]
    description = "Bastion Security Group"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rdp_from_bastion" {
  name        = "${var.prefix}_RDP_FROM_BASTION"
  description = "RDP from Bastion"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "TCP"
    cidr_blocks = ["${aws_instance.bastion.private_ip}/32"]
    description = "Bastion Security Group"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "mysql_from_bastion" {
  name        = "${var.prefix}_MYSQL_FROM_BASTION"
  description = "MySQL from Bastion"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "TCP"
    cidr_blocks = ["${aws_instance.bastion.private_ip}/32"]
    description = "Bastion Security Group"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "postgresql_from_bastion" {
  name        = "${var.prefix}_POSTGRESQL_FROM_BASTION"
  description = "PostgreSQL from Bastion"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "TCP"
    cidr_blocks = ["${aws_instance.bastion.private_ip}/32"]
    description = "Bastion Security Group"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "mssql_from_bastion" {
  name        = "${var.prefix}_MSSQL_FROM_BASTION"
  description = "MSSQL from Bastion"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "TCP"
    cidr_blocks = ["${aws_instance.bastion.private_ip}/32"]
    description = "Bastion Security Group"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

######################################################################################################################################################################
# Outputs detailing SSH Tunnel Strings 
######################################################################################################################################################################
output "information" {
  value = <<-EOF

    # Change key security and log into Bastion
    chmod 400 ${aws_key_pair.generated_key.key_name}.pem
    ssh -i ${aws_key_pair.generated_key.key_name}.pem -p ${var.ssh_port} ec2-user@${aws_instance.bastion.public_ip}

    ssh -i ${aws_key_pair.generated_key.key_name}.pem -p ${var.ssh_port} ec2-user@${aws_instance.bastion.public_ip} -N -L 11222:[AMAZON-LINUX-IP]:22
    ssh -i ${aws_key_pair.generated_key.key_name}.pem -p ${var.ssh_port} ec2-user@${aws_instance.bastion.public_ip} -N -L 11322:[UBUNTU-IP]:22
    ssh -i ${aws_key_pair.generated_key.key_name}.pem -p ${var.ssh_port} ec2-user@${aws_instance.bastion.public_ip} -N -L 13389:[WINDOWS-IP]:3389
    ssh -i ${aws_key_pair.generated_key.key_name}.pem -p ${var.ssh_port} ec2-user@${aws_instance.bastion.public_ip} -N -L 13306:[MYSQL-ENDPOINT]:3306
    ssh -i ${aws_key_pair.generated_key.key_name}.pem -p ${var.ssh_port} ec2-user@${aws_instance.bastion.public_ip} -N -L 15432:[POSTGRESQL-ENDPOINT]:5432
    ssh -i ${aws_key_pair.generated_key.key_name}.pem -p ${var.ssh_port} ec2-user@${aws_instance.bastion.public_ip} -N -L 11433:[MSSQL-ENDPOINT]:1433

  EOF
}
