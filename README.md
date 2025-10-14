# PowerScriptsRepo

## Description
A collection of PowerShell scripts for various system administration and maintenance tasks.

## Disclaimer
These scripts are provided as-is, without warranty of any kind. Users are free to use and modify them, but do so at their own risk. The author assumes no responsibility for any issues that may arise from their use.

## Scripts

### DisableNBT.ps1
A PowerShell script to disable NetBios over TCP/IP on network interfaces. This can help improve network security by disabling an older protocol that may not be needed in modern environments.

### Get-TemplateACLs_v2.ps1
A utility script to retrieve and analyze certificate template permissions from Active Directory. The script:
- Retrieves all certificate templates from Active Directory
- Filters templates based on a specified Certificate Authority server
- Extracts and displays Access Control Lists (ACLs) including special permissions

Usage:
```powershell
.\Get-TemplateACLs.ps1 -IssuingCertServer "YourCertServerName"
```

### keepalive.ps1
A simple but effective script that prevents system sleep by simulating an F15 key press. This is a lightweight alternative to scripts that use mouse movement or more complex actions to keep a system active. Useful for situations where system sleep needs to be prevented without modifying system power settings.