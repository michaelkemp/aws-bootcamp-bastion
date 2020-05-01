terraform {
  required_version = ">= 0.12.20"
}

provider "aws" {
  version = "~>2.59.0"
  region  = "us-west-2"
}

provider "aws" {
  version = "~>2.59.0"
  region  = "us-west-2"
  alias   = "us-west-2"
  profile = "byu-org-trn"
}

variable "my_ip" {
  type = string
  # https://www.whatismyip.com/
}

variable "my_key" {
  type    = string
  default = "kempy-org-trn"
}

resource "aws_security_group" "self_referencing_ssh" {
  name        = "self_referencing_ssh"
  description = "Self Referencing SSH"
  vpc_id      = "vpc-0d4f716433bda1413"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    self        = true
    description = "Self"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "self_referencing_rdp" {
  name        = "self_referencing_rdp"
  description = "Self Referencing RDP"
  vpc_id      = "vpc-0d4f716433bda1413"
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "TCP"
    self        = true
    description = "Self"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "bastion_security_group" {
  name        = "bastion_security_group"
  description = "Security Group for Bastion"
  vpc_id      = "vpc-0d4f716433bda1413"
  ingress {
    from_port   = 22222
    to_port     = 22222
    protocol    = "TCP"
    cidr_blocks = [var.my_ip]
    description = "SSH Ingress"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

/* Retrieve the AMI ID for the most recent Amazon Linux 2 image */
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

/* Retrieve the AMI ID for the most recent Microsoft Windows image */
data "aws_ami" "microsoft-windows" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base*"]
  }
}

/* Create an EC2 image in the Public Subnet using the Amazon Linux 2 AMI */
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon-linux-2.id
  instance_type = "t2.micro"
  tags = {
    Name = "Bastion"
  }
  subnet_id                   = "subnet-071692a02d8fead70" #Public A Subnet
  associate_public_ip_address = true
  key_name                    = var.my_key
  security_groups             = [aws_security_group.bastion_security_group.id, aws_security_group.self_referencing_ssh.id, aws_security_group.self_referencing_rdp.id]

  lifecycle {
    ignore_changes = [security_groups]
  }
  user_data = file("change-port.sh")
}

/* Create an EC2 image in the Private Subnet using the Microsoft Windows Server 2019 AMI */
resource "aws_instance" "windows" {
  ami           = data.aws_ami.microsoft-windows.id
  instance_type = "t2.large"
  tags = {
    Name = "Windows"
  }
  subnet_id                   = "subnet-039dee9d86772d9a0" #Private A Subnet
  associate_public_ip_address = false
  key_name                    = var.my_key
  security_groups             = [aws_security_group.self_referencing_rdp.id]
  lifecycle {
    ignore_changes = [security_groups]
  }

}

/* Create an EC2 image in the Private Subnet using the Amazon Linux 2 AMI */
resource "aws_instance" "linux" {
  ami           = data.aws_ami.amazon-linux-2.id
  instance_type = "t2.micro"
  tags = {
    Name = "Linux"
  }
  subnet_id                   = "subnet-039dee9d86772d9a0" #Private A Subnet
  associate_public_ip_address = true
  key_name                    = var.my_key
  security_groups             = [aws_security_group.self_referencing_ssh.id]
  lifecycle {
    ignore_changes = [security_groups]
  }
}


output "bastion-dns" {
  value = aws_instance.bastion.public_dns
}

output "windows-ip" {
  value = aws_instance.windows.private_ip
}

output "linux-ip" {
  value = aws_instance.linux.private_ip
}

output "rdp-via-ssh-tunnel" {
  value = "ssh -p 22222 -N -L 3399:${aws_instance.windows.private_ip}:3389 ec2-user@${aws_instance.bastion.public_dns} -i ${var.my_key}.pem"
}

output "ssh-via-ssh-tunnel" {
  value = "ssh -p 22222 -N -L 2222:${aws_instance.linux.private_ip}:22 ec2-user@${aws_instance.bastion.public_dns} -i ${var.my_key}.pem"
}
