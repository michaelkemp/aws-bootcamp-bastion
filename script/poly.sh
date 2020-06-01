#!/bin/bash

#aws polly synthesize-speech --output-format mp3 --voice-id Amy --text file://00-intro.txt 00-intro.mp3
#aws polly synthesize-speech --output-format mp3 --voice-id Amy --text file://01-wsl.txt 01-wsl.mp3
#aws polly synthesize-speech --output-format mp3 --voice-id Amy --text file://02-vscode.txt 02-vscode.mp3
#aws polly synthesize-speech --output-format mp3 --voice-id Amy --text file://03-awscli.txt 03-awscli.mp3
#aws polly synthesize-speech --output-format mp3 --voice-id Amy --text file://03a-unzip-pip3.txt 03a-unzip-pip3.mp3
#aws polly synthesize-speech --output-format mp3 --voice-id Amy --text file://04-awslogin.txt 04-awslogin.mp3
#aws polly synthesize-speech --output-format mp3 --voice-id Amy --text file://05-terraform.txt 05-terraform.mp3
#aws polly synthesize-speech --output-format mp3 --voice-id Amy --text file://06-train-account.txt 06-train-account.mp3

aws polly synthesize-speech --output-format mp3 --voice-id Amy --text file://04a-vim-bashrc.txt 04a-vim-bashrc.mp3

