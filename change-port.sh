#!/bin/bash
sudo yum update -y && sudo yum upgrade -y
sudo sed -i 's/#Port 22/Port 22222/g' /etc/ssh/sshd_config
sudo service sshd restart
sudo yum install mysql -y 
