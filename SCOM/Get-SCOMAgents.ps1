# Pull from PRD
import-module "operationsmanager"
$MS = "PRDServer"
New-SCOMManagementGroupConnection -ComputerName $MS
$AllAgents = Get-SCOMAgent
$exportpath = "C:\temp\SCOMAgents_PRD.csv"
write-host $exportpath
$AllAgents | Export-Csv -NoTypeInformation $exportpath
Get-SCOMManagementGroupConnection | Remove-SCOMManagementGroupConnection

#Pull From DEV
import-module "operationsmanager"
$MS = "DEVSERVER"
New-SCOMManagementGroupConnection -ComputerName $MS
$AllAgents = Get-SCOMAgent
$exportpath = "C:\temp\SCOMAgents_DEV.csv"
write-host $exportpath
$AllAgents | Export-Csv -NoTypeInformation $exportpath
Get-SCOMManagementGroupConnection | Remove-SCOMManagementGroupConnection
