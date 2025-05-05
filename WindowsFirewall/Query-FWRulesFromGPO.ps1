#Rules From GPO Only - Export to CSV
$FirewallRulesfromGPO = Get-NetFirewallRule -PolicyStore RSOP -PolicyStoreSourceType GroupPolicy
$FirewallRulesfromGPO | Export-Csv -NoTypeInformation -Path C:\temp\FirewallRulesfromGPO.csv

#ALL RULE DETAILS - PROBABLY TOO MUCH INFORMATION

foreach ($rule in $FirewallRulesfromGPO){
write-host Name: $rule.Name
write-host DisplayName: $Rule.DisplayName
$FirewallRuleName = $rule.Name
write-host "Security Filter" -ForegroundColor Green
$FirewallRulesfromGPO | ? {$_.Name -eq $FirewallRuleName} | Get-NetFirewallSecurityFilter | ft
write-host "Port Filter" -ForegroundColor Green
$FirewallRulesfromGPO | ? {$_.Name -eq $FirewallRuleName} | Get-NetFirewallPortFilter | ft
write-host "Service Filter" -ForegroundColor Green
$FirewallRulesfromGPO | ? {$_.Name -eq $FirewallRuleName} | Get-NetFirewallServiceFilter | ft
#write-host "Interface Type Filter" -ForegroundColor Green
#$FirewallRulesfromGPO | ? {$_.Name -eq $FirewallRuleName} | Get-NetFirewallInterfaceTypeFilter | ft
#write-host "Interface Filter" -ForegroundColor Green
#$FirewallRulesfromGPO | ? {$_.Name -eq $FirewallRuleName} | Get-NetFirewallInterfaceFilter | ft
write-host "Application Filter" -ForegroundColor Green
$FirewallRulesfromGPO | ? {$_.Name -eq $FirewallRuleName} | Get-NetFirewallApplicationFilter | ft
write-host "Address Filter" -ForegroundColor Green
$FirewallRulesfromGPO | ? {$_.Name -eq $FirewallRuleName} | Get-NetFirewallAddressFilter | ft
}

#RSOP RULES WHERE THE ADDRESS FILTER IS FILTERED DOWN TO SOMETHING BESIDES ANY
Get-NetFirewallAddressFilter -PolicyStore RSOP | ? {$_.LocalAddress -ne "Any" -or $_.RemoteAddress -ne "Any"} | select InstanceId, CreationClassName, LocalAddress, RemoteAddress


