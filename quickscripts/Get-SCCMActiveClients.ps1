Import-Module ($env:SMS_ADMIN_UI_PATH -replace 'i386','ConfigurationManager.psd1') -Force
#import-module "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
$sitecode = 'MYSITECODE'
$all = Get-CMDevice
$active_Clean = $all | ? {$_.IsClient -eq "True" -and $_.IsActive -eq "True"} | select ADLastLogonTime,ADSiteName,BoundaryGroups,ClientActiveStatus,ClientCertType,ClientCheckPass,ClientState,ClientType,CoManaged,CurrentLogonUser,DeviceOS,DeviceOSBuild,Domain,IsActive,IsApproved,IsAssigned,IsBlocked,IsClient,IsDecommissioned,IsDirect,IsInternetEnabled,IsMDMActive,IsObsolete,IsSupervised,IsVirtualMachine,LastActiveTime,LastClientCheckTime,LastDDR,LastFUErrorDetail,LastHardwareScan,LastInstallationError,LastLogonUser,LastPolicyRequest,LastSoftwareScan,LastStatusMessage,MACAddress,ManagementAuthority,Name,PrimaryUser,ResourceID,ResourceType,SerialNumber,SiteCode,SMBIOSGUID,SMSID,UserName
$active_Clean | Export-Csv -NoTypeInformation C:\temp\activesccmclients.csv
