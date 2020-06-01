# aws-bootcamp-bastion


## Set Up Windows with Windows Subsystem for Linux (WSL)

- Enable [WSL](https://docs.microsoft.com/en-us/windows/wsl/install-win10)
    - Open PowerShell as Administrator and run
        - ```Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux```
- Install *Ubuntu 18.04 LTS* from the Microsoft Store
    - You will be asked for a Username and Password; this does not need to be the same as your Windows username/password
- Install [Visual Studio Code](https://code.visualstudio.com/)
- Connect VSCode to WSL
    - Open Ubuntu and run the command
        - ```code .```


## Install AWS Command Line Tool, BYU's AWSlogin, and Terraform

- Open (WSL) Ubuntu
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
- Install [Terraform](https://www.terraform.io/downloads.html)
    - ```curl "https://releases.hashicorp.com/terraform/0.12.24/terraform_0.12.24_linux_amd64.zip" -o "terraform.zip"```
    - ```unzip terraform.zip```
    - ```mv terraform .local/bin/terraform```
    - ```terraform --version```


## BYU Training Account

- To request access to the BYU Training account, visit [https://go.byu.edu/AWSTrainingAccountRequest](https://go.byu.edu/AWSTrainingAccountRequest)
    - Although the training account is nuked weekly, it is kind to clean up (delete) your infrastructure after you have finished with it.
- Use BYU's commandline ```awslogin``` tool to connect via the command line, or got to [https://awslogin.byu.edu/](https://awslogin.byu.edu/) to log in via the console.
- Command line example:
    - ```awslogin --account byu-org-trn --role PowerUser```


## Terraform Infrastructure and Bastion Server 

- ```mkdir ~/GitRepos```
- ```cd ~/GitRepos```
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
    - ```cd ~/GitRepos/aws-bootcamp-bastion/infrastructure```
    - ```terraform init```
    - ```terraform apply```
    - Accept the changes ```yes```
    - Once the Infrastructure is terraformed
        - Change the security on your PEM file
            - ```chmod 400 prefix-infrastructure-key.pem```
            - note the IP addresses or endpoints of your infrastructure
    - Terraform will build a MySQL Database in the Data Subnet, and 3 EC2 Instances in the Private Subnet
    - Once we are finished, use ```terraform destroy``` to remove remove the infrastructure.

- To *Terraform* the Bastion Server
    - ```cd ~/GitRepos/aws-bootcamp-bastion/bastion```
    - ```terraform init```
    - ```terraform apply```
    - Accept the changes ```yes```
    - Once the Bastion is terraformed
        - In the console, **attach the created security groups** to your infrastructure
        - Change the security on your PEM file
            - ```chmod 400 prefix-bastion-key.pem```
        - SSH to your Bastion Server and accept the certificate
            - ```ssh -i prefix-bastion-key.pem -p 22222 ec2-user@44.144.44.144```
        - Use the terraform outputs to create tunnels to the test infrastructure
            - ```ssh -i prefix-bastion-key.pem -p 22222 ec2-user@44.144.44.144 -N -L 13306:mysql.endpoint:3306```
            - ```ssh -i prefix-bastion-key.pem -p 22222 ec2-user@44.144.44.144 -N -L 11122:linux.endpoint:22```
            - ```ssh -i prefix-bastion-key.pem -p 22222 ec2-user@44.144.44.144 -N -L 13389:windows.endpoint:3389```
    - Once we are finished, detach the security groups, and use ```terraform destroy``` to remove remove the bastion.


## Understanding SSH Tunnels

- [Tunneling](https://www.ssh.com/ssh/tunneling/example) example
- The ```ssh -L``` command forwards a port on **your machine** throught your **bastion server**, to a **remote machine**.
- ```-N``` *Do not execute a remote command.* This is useful for just forwarding ports. Which is the case we are exploiting. 
- You generally don't use the standard port at your end of the tunnel, in case you already have something listening on this port.
- Examples:
    - To ssh to an AWS Linux bastion running at 44.144.44.144 with key bastion-key.pem
        - ```ssh -i bastion-key.pem ec2-user@44.144.44.144```
    - ssh to the same machine on a non standard port 22222 (not port 22) - *the machine must be setup to listen/respond on the non standard port*
        - ```ssh -i bastion-key.pem -p 22222 ec2-user@44.144.44.144```
    - create a tunnel from the *local machine* on port **13006** through the *bastion* to a remote MySQL Server (**remote.mysql.amazon.com**) on port **3306**
        - ```ssh -i bastion-key.pem -p 22222 ec2-user@44.144.44.144 -N -L 13306:the.remote.mysql.amazon.com:3306```     
- TCP/UDP ports range from 0 to 65535; when choosing a *local* port to forward, choose a number between 1024 and 49151 that is not in use.
- With a tunnel running, connect to the infrastructure as if it is running locally - 127.0.0.1
    - ```mysql --host=127.0.0.1 --port=13306 -u username -p password```
    - ```ssh -i infrastructure-key.pem -p 11122 ubuntu@127.0.0.1```
    - ```ssh -i infrastructure-key.pem -p 11122 ec2-user@127.0.0.1```

