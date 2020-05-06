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
    - Add local/bin to path
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

