import-module "operationsmanager"
$MS = "prdserver"
New-SCOMManagementGroupConnection -ComputerName $MS
$AllAgents = Get-SCOMAgent
$AllAgents | Export-Csv -NoTypeInformation C:\temp\SCOMAgents_PRD.csv
Get-SCOMManagementGroupConnection | Remove-SCOMManagementGroupConnection


import-module "operationsmanager"
$MS = "devserver"
New-SCOMManagementGroupConnection -ComputerName $MS
$AllAgents = Get-SCOMAgent
$AllAgents | Export-Csv -NoTypeInformation C:\temp\SCOMAgents_DEV.csv
Get-SCOMManagementGroupConnection | Remove-SCOMManagementGroupConnection
