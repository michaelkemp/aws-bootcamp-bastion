# aws-bootcamp-bastion

## Set Up Windows with Windows Subsystem for Linux (WSL)

- Enable [WSL](https://docs.microsoft.com/en-us/windows/wsl/install-win10)
    - Open PowerShell as Administrator and run
        - ```Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux```
- Install Ubuntu from the Microsoft Store
- Install Visual Studio Code
- Connect VSCode to WSL
    - Open Ubuntu and run the command 
        - ```code .```

## Install aws command line tool, BYU's awslogin, and terraform

- Open Ubuntu
- Add pip3 and unzip
    - ```sudo apt install unzip```
    - ```sudo apt install python3-pip```
- Install [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html)
    - ```curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"```
    - ```unzip awscliv2.zip```
    - ```sudo ./aws/install```
    - ```aws --version```
- Install [BYU's awslogin](https://github.com/byu-oit/awslogin)
    - ```pip3 install --upgrade byu_awslogin```
- Add $HOME/.local/bin to path
    - ```
        vim .bashrc
            if [ -d "$HOME/.local/bin" ] ; then
                PATH="$HOME/.local/bin:$PATH"
            fi
        source .bashrc
    ```
- Install [Terraform](https://www.terraform.io/downloads.html)
    - ```curl "https://releases.hashicorp.com/terraform/0.12.24/terraform_0.12.24_linux_amd64.zip" -o "terraform.zip"```
    - ```unzip terraform.zip```
    - ```mv terraform .local/bin/terraform```

## Terraform Bastion Infrastructure 

- ```mkdir GitRepos```
- ```cd GitRepos```
- ```git clone https://github.com/michaelkemp/aws-bootcamp-bastion.git```
- ```cd aws-bootcamp-bastion```
- ```code .```

- Edit infrastructure\terraform.tfvars
    - This file contains the VPC-ID and Subnet-IDs (Private and Data) that the test infrastructure will be created in  
    - Change the *prefix* value to your own NetId (or something memorable)

- Edit bastion\terraform.tfvars
    - This file contains the VPC-ID and Subnet-ID (Public) that the Bastion Server (and Security groups) will be created in
    - Change the *prefix* value to your own NetId (or something memorable)
    - Change the non standard port that you would like to SSH into (rather than using port 22) 

- To *Terraform* Test Infrastructure
    - ```cd aws-bootcamp-bastion/infrastructure```
    - ```terraform init```
    - ```terraform apply```
    - Accept the changes ```yes```
    - Once the Infrastructure is Terraformed
        - Change the security on your PEM file
            - ```chmod 400 prefix-infrastructure-key.pem```
            - note the IP addresses or endpoints of your infrastructure
    - Terraform will build a MySQL Database in the Data Subnet, and 3 EC2 Instances in the Private Subnet

- To *Terraform* the Bastion Server
    - ```cd aws-bootcamp-bastion/bastion```
    - ```terraform init```
    - ```terraform apply```
    - Accept the changes ```yes```
    - Once the Infrastructure is Terraformed
        - In the console, attach the created security groups to your infrastructure
        - Change the security on your PEM file
            - ```chmod 400 prefix-infrastructure-key.pem```
        - SSH to your Bastion Server and accept the Certificate
            - ```ssh -i prefix-bastion-key.pem -p 22222 ec2-user@123.123.123.123```
        - Use the terraform outputs to create tunnels to the test infrastructure
            - ```ssh -i prefix-bastion-key.pem -p 22222 -N -L 13306:mysql.endpoint:3306 ec2-user@123.123.123.123```

## Understanding SSH Tunnels

- [Tunneling](https://www.ssh.com/ssh/tunneling/example) example
- The ```ssh -L``` command forwards a port on Your Machine throught your Bastion Server, to a remote machine.
- You generally don't use the standard port the your end of the tunnel, in case you already have something running on this port.
- Examples:
    - ssh to my AWS Linux bastion running at ec2-44-144-44-144.us-west-2.compute.amazonaws.com with my key.pem
        - ```ssh -i key.pem ec2-user@44.144.44.144```
    - ssh to the same machine on a non standard port 22222 (not port 22) - *the machine must be setup to listen/respond on the non standard port*
        - ```ssh -i key.pem -p 22222 ec2-user@44.144.44.144```
    - create a tunnel from my Local Machine on port 13006 through the Bastion to a remote MySQL Server (the.remote.mysql.amazon.com) on port 3306
        - ```ssh -i kempy2-bastion-key.pem -p 22222 -N -L 13306:the.remote.mysql.amazon.com:3306 ec2-user@44.144.44.144```     
            - Tunnel through the bastion: 
                - **ssh -i kempy2-bastion-key.pem -p 22222 -N -L** 13306:the.remote.mysql.amazon.com:3306 **ec2-user@44.144.44.144**
            - from local port 13306: 
                - ssh -i kempy2-bastion-key.pem -p 22222 -N -L **13306**:the.remote.mysql.amazon.com:3306 ec2-user@44.144.44.144
            - to remote server, remote port 3306: 
                - ssh -i kempy2-bastion-key.pem -p 22222 -N -L 13306:**the.remote.mysql.amazon.com:3306** ec2-user@44.144.44.144 