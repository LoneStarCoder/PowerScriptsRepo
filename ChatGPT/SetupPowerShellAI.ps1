#Install it
#https://github.com/dfinke/PowerShellAI
Install-Module -Name PowerShellAI
Import-Module PowerShellAI

#Checkout the commands
Get-Command -Module PowerShellAI | Select-Object Name

#Set your API Key
$env:OpenAIKey = ""
echo $env:OpenAIKey

Get-GPT3Completion "Hello"