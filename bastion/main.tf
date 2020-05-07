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
  default = 22
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

# Find image with AMI: aws ec2 describe-images --image-ids ami-003634241a8fcdec0
######################################################################################################################################################################
# Retrieve the AMI ID for the most recent Amazon Linux 2 image 
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

######################################################################################################################################################################
# Security Group to attach to the Bastion Server - External SSH Traffic on an obscure port 
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
# Security Group to allow the SSH from the Bastion
######################################################################################################################################################################
resource "aws_security_group" "ssh_from_bastion" {
  name        = "${var.prefix}_ssh_from_bastion"
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

######################################################################################################################################################################
# Security Group to allow the RDP from the Bastion 
######################################################################################################################################################################
resource "aws_security_group" "rdp_from_bastion" {
  name        = "${var.prefix}_rdp_from_bastion"
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

######################################################################################################################################################################
# Security Group to allow the MySQL from the Bastion
######################################################################################################################################################################
resource "aws_security_group" "mysql_from_bastion" {
  name        = "${var.prefix}_mysql_from_bastion"
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

######################################################################################################################################################################
# Security Group to allow the PostgreSQL from the Bastion
######################################################################################################################################################################
resource "aws_security_group" "postgresql_from_bastion" {
  name        = "${var.prefix}_postgresql_from_bastion"
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

######################################################################################################################################################################
# Security Group to allow the MSSQL from the Bastion
######################################################################################################################################################################
resource "aws_security_group" "mssql_from_bastion" {
  name        = "${var.prefix}_mssql_from_bastion"
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

output "bastion" {
  value = <<-EOF

    chmod 400 ${aws_key_pair.generated_key.key_name}.pem
    ssh -p ${var.ssh_port} ec2-user@${aws_instance.bastion.public_dns} -i ${aws_key_pair.generated_key.key_name}.pem

  EOF
}

output "ssh-tunnels" {
  value = <<-EOF

    ssh -p ${var.ssh_port} -N -L 13389:[WINDOWS-IP]:3389 ec2-user@${aws_instance.bastion.public_dns} -i ${aws_key_pair.generated_key.key_name}.pem
    ssh -p ${var.ssh_port} -N -L 11122:[UBUNTU-IP]:22 ec2-user@${aws_instance.bastion.public_dns} -i ${aws_key_pair.generated_key.key_name}.pem
    ssh -p ${var.ssh_port} -N -L 13306:[MYSQL-ENDPOINT]:3306 ec2-user@${aws_instance.bastion.public_dns} -i ${aws_key_pair.generated_key.key_name}.pem
    ssh -p ${var.ssh_port} -N -L 15432:[POSTGRESQL-ENDPOINT]:5432 ec2-user@${aws_instance.bastion.public_dns} -i ${aws_key_pair.generated_key.key_name}.pem
    ssh -p ${var.ssh_port} -N -L 11433:[MSSQL-ENDPOINT]:1433 ec2-user@${aws_instance.bastion.public_dns} -i ${aws_key_pair.generated_key.key_name}.pem

  EOF
}
