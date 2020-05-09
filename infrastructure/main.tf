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

variable "private_subnet" {
  type    = string
  default = ""
}

variable "data_subnets" {
  type    = list(string)
  default = []
}

######################################################################################################################################################################
# Create Key
######################################################################################################################################################################
resource "tls_private_key" "infrastructure" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "generated_key" {
  key_name   = "${var.prefix}-infrastructure-key"
  public_key = tls_private_key.infrastructure.public_key_openssh
}
resource "local_file" "write-key" {
  content  = tls_private_key.infrastructure.private_key_pem
  filename = "${path.module}/${var.prefix}-infrastructure-key.pem"
}

######################################################################################################################################################################
# Security Groups
######################################################################################################################################################################
resource "aws_security_group" "SSH_security_group" {
  name        = "${var.prefix}_SSH"
  description = "SSH Security Group"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    self        = true
    description = "Self Referencing"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "RDP_security_group" {
  name        = "${var.prefix}_RDP"
  description = "RDP Security Group"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "TCP"
    self        = true
    description = "Self Referencing"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "MYSQL_security_group" {
  name        = "${var.prefix}_MYSQL"
  description = "MYSQL Security Group"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "TCP"
    self        = true
    description = "Self Referencing"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
# Test Amazon Linux Server - Create an EC2 image in the Private Subnet using the Amazon Linux 2 AMI
######################################################################################################################################################################
resource "aws_instance" "linux" {
  ami           = data.aws_ami.amazon-linux-2.id
  instance_type = "t2.micro"
  tags = {
    Name = "${var.prefix}-Amazon-Linux-2"
  }
  subnet_id                   = var.private_subnet
  associate_public_ip_address = false
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [aws_security_group.SSH_security_group.id]
}

######################################################################################################################################################################
# Test Ubuntu Server - Create an EC2 image in the Private Subnet using the Ubuntu Linux AMI
######################################################################################################################################################################
resource "aws_instance" "ubuntu" {
  ami           = data.aws_ami.ubuntu-linux.id
  instance_type = "t2.micro"
  tags = {
    Name = "${var.prefix}-Ubuntu"
  }
  subnet_id                   = var.private_subnet
  associate_public_ip_address = false
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [aws_security_group.SSH_security_group.id]
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
  subnet_id                   = var.private_subnet
  associate_public_ip_address = false
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [aws_security_group.RDP_security_group.id]
  get_password_data           = true
}

######################################################################################################################################################################
# Test MySQL Database - Create a DB Subnet Group and MySQL Database in the Data Subnet
######################################################################################################################################################################
resource "aws_db_subnet_group" "mysql-rds-subnet-group" {
  name       = "${var.prefix}-mysql-rds-subnet-group"
  subnet_ids = var.data_subnets
  tags = {
    Name = "MySQL RDS subnet group"
  }
}
resource "random_password" "rds-password" {
  length  = 32
  special = false
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
  vpc_security_group_ids = [aws_security_group.MYSQL_security_group.id]
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

output "information" {
  value = <<-EOF

    chmod 400 ${aws_key_pair.generated_key.key_name}.pem

    # IPs and Endpoints
    # Amazon Linux: ${aws_instance.linux.private_ip}
    # Ubuntu Linux: ${aws_instance.ubuntu.private_ip}
    # Windows Srvr: ${aws_instance.windows.private_ip}
    # MySQL Server: ${aws_db_instance.mysql.address}

    # SSH to Linux Servers through SSH Tunnel
    ssh -i ${aws_key_pair.generated_key.key_name}.pem -p 11122 ubuntu@127.0.0.1
    ssh -i ${aws_key_pair.generated_key.key_name}.pem -p 11122 ec2-user@127.0.0.1

    # MySql through SSH Tunnel
    mysql --host=127.0.0.1 --port=13306 -uadmin -p${random_password.rds-password.result}

    # Windows RDS through SSH Tunnel
    Address: 127.0.0.1:13389
    Username: Administrator
    Password: [see below]

    # Get Windows Password
    aws ec2 get-password-data --instance-id ${aws_instance.windows.id} --priv-launch-key ${aws_key_pair.generated_key.key_name}.pem

  EOF
}
