#!/bin/bash

aws polly synthesize-speech --output-format mp3 --voice-id Amy --text file://intro.txt intro.mp3

aws polly synthesize-speech --output-format mp3 --voice-id Amy --text file://01-wsl.txt 01-wsl.mp3
aws polly synthesize-speech --output-format mp3 --voice-id Amy --text file://02-vscode.txt 02-vscode.mp3
aws polly synthesize-speech --output-format mp3 --voice-id Amy --text file://03-awscli.txt 03-awscli.mp3
aws polly synthesize-speech --output-format mp3 --voice-id Amy --text file://04-awslogin.txt 04-awslogin.mp3
aws polly synthesize-speech --output-format mp3 --voice-id Amy --text file://05-terraform.txt 05-terraform.mp3

