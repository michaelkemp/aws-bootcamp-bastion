terraform {
  required_version = ">= 0.12.24"
}

provider "aws" {
  version = "~>2.59.0"
  region  = "us-west-2"
}

variable "my_ip" {
  type    = string
  default = "128.187.0.0/16"
}
variable "prefix" {
  type    = string
  default = ""
}
variable "my_key" {
  type    = string
  default = ""
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

######################################################################################################################################################################
# BASTION - Create an EC2 Instance in the Public Subnet using the Amazon Linux 2 AMI 
######################################################################################################################################################################
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon-linux-2.id
  instance_type = "t2.micro"
  tags = {
    Name = "${var.prefix}-Bastion"
  }
  subnet_id                   = "subnet-071692a02d8fead70" #Public A Subnet
  associate_public_ip_address = true
  key_name                    = var.my_key
  vpc_security_group_ids      = [aws_security_group.bastion_security_group.id]
  user_data                   = file("change-port.sh")
}

######################################################################################################################################################################
######################################################################################################################################################################
#
#                Connect to the following via the BASTION: Ubuntu Linux, Windows 2019, MySQL 
#
######################################################################################################################################################################
######################################################################################################################################################################

######################################################################################################################################################################
# Security Group to allow the Bastion to attach to the Ubuntu Server in the Private Subnet - SSH Traffic
######################################################################################################################################################################
resource "aws_security_group" "bastion_to_ssh" {
  name        = "${var.prefix}_bastion_to_ssh"
  description = "Bastion to SSH"
  vpc_id      = "vpc-0d4f716433bda1413"
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "TCP"
    security_groups = [aws_security_group.bastion_security_group.id]
    description     = "Bastion Security Group"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

######################################################################################################################################################################
# Security Group to allow the Bastion to attach to the Windows Server in the Private Subnet - RDP Traffic 
######################################################################################################################################################################
resource "aws_security_group" "bastion_to_rdp" {
  name        = "${var.prefix}_bastion_to_rdp"
  description = "Bastion to RDP"
  vpc_id      = "vpc-0d4f716433bda1413"
  ingress {
    from_port       = 3389
    to_port         = 3389
    protocol        = "TCP"
    security_groups = [aws_security_group.bastion_security_group.id]
    description     = "Bastion Security Group"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

######################################################################################################################################################################
# Security Group to allow the Bastion to attach to the MySQL RDS in the Data Subnet - MySQL Traffic
######################################################################################################################################################################
resource "aws_security_group" "bastion_to_mysql" {
  name        = "${var.prefix}_bastion_to_mysql"
  description = "Bastion to MySQL"
  vpc_id      = "vpc-0d4f716433bda1413"
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "TCP"
    security_groups = [aws_security_group.bastion_security_group.id]
    description     = "Bastion Security Group"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

######################################################################################################################################################################
# Retrieve the AMI ID for the most recent Microsoft Windows image 
######################################################################################################################################################################
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

######################################################################################################################################################################
# Retrieve the AMI ID for the most recent Ubuntu Linux image 
######################################################################################################################################################################
data "aws_ami" "ubuntu-linux" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic*"]
  }
}

######################################################################################################################################################################
# Test Windows Server - Create an EC2 Instance in the Private Subnet using the Microsoft Windows Server 2019 AMI
######################################################################################################################################################################
resource "aws_instance" "windows" {
  ami           = data.aws_ami.microsoft-windows.id
  instance_type = "t2.large"
  tags = {
    Name = "${var.prefix}-Windows"
  }
  subnet_id                   = "subnet-039dee9d86772d9a0" #Private A Subnet
  associate_public_ip_address = false
  key_name                    = var.my_key
  vpc_security_group_ids      = [aws_security_group.bastion_to_rdp.id]
}

######################################################################################################################################################################
# Test Ubuntu Server - Create an EC2 image in the Private Subnet using the Ubuntu Linux 2 AMI
######################################################################################################################################################################
resource "aws_instance" "ubuntu" {
  ami           = data.aws_ami.ubuntu-linux.id
  instance_type = "t2.micro"
  tags = {
    Name = "${var.prefix}-Ubuntu"
  }
  subnet_id                   = "subnet-039dee9d86772d9a0" #Private A Subnet
  associate_public_ip_address = false
  key_name                    = var.my_key
  vpc_security_group_ids      = [aws_security_group.bastion_to_ssh.id]
}

######################################################################################################################################################################
# Test MySQL Database - Create a DB Subnet Group and MySQL Database in the Data Subnet
######################################################################################################################################################################
resource "aws_db_subnet_group" "mysql-rds-subnet-group" {
  name       = "${var.prefix}-mysql-rds-subnet-group"
  subnet_ids = ["subnet-0a7749029f9c6cc02", "subnet-03d2524cefe73b748"]
  tags = {
    Name = "MySQL RDS subnet group"
  }
}
resource "random_password" "rds-password" {
  length = 32
}
resource "aws_db_instance" "mysql" {
  identifier             = "${var.prefix}-mysql-rds"
  skip_final_snapshot    = true
  deletion_protection    = false
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  username               = "admin"
  password               = random_password.rds-password.result
  db_subnet_group_name   = aws_db_subnet_group.mysql-rds-subnet-group.name
  vpc_security_group_ids = [aws_security_group.bastion_to_mysql.id]
}
resource "aws_ssm_parameter" "mysql-password" {
  name      = "${var.prefix}-mysql-password"
  value     = random_password.rds-password.result
  type      = "String"
  overwrite = true
}

######################################################################################################################################################################
# Outputs detailing SSH Tunnel Strings 
######################################################################################################################################################################

output "bastion" {
  value = <<EOF

ssh -p 22222 ec2-user@${aws_instance.bastion.public_dns} -i ${var.my_key}.pem
mysql --host=${aws_db_instance.mysql.address} -u admin -p ${random_password.rds-password.result}

EOF
}

output "ssh-tunnels" {
  value = <<EOF

ssh -p 22222 -N -L 13389:${aws_instance.windows.private_ip}:3389 ec2-user@${aws_instance.bastion.public_dns} -i ${var.my_key}.pem
ssh -p 22222 -N -L 11122:${aws_instance.ubuntu.private_ip}:22 ec2-user@${aws_instance.bastion.public_dns} -i ${var.my_key}.pem
ssh -p 22222 -N -L 13306:${aws_db_instance.mysql.endpoint} ec2-user@${aws_instance.bastion.public_dns} -i ${var.my_key}.pem

EOF
}

output "through-bastion" {
  value = <<EOF

mysql --host=127.0.0.1 --port=13306 -u admin -p ${random_password.rds-password.result}
ssh -i ${var.my_key}.pem -p 11122 ubuntu@127.0.0.1

EOF
}
