# PowerScriptsRepo

## Description
Just Random PowerShell Scripts

## Disclaimer
Feel free to use and modify, but I am not responsible for any issues you may cause. Use at your own risk.

## Scripts

### DisableNBT.ps1
Disable NetBios over TCP/IP.

### Get-TemplateACLs_v2.ps1
Pull all of the certificate templates from AD, and then filter them down only to the list of templates that have been published to a specific Issue Cert Server. Get the ACLs, including special permissions and export to CSV.
- EXAMPLE: .\Get-TemplateACLs.ps1 -IssuingCertServer "YourCertServerName"

### keepalive.ps1
Presses the magic "F15" key to keep your computer from sleeping - in most cases. There are other scripts out there that move the mouse and such, but for me, this is sufficient.
