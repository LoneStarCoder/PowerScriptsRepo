import-module OperationsManager

#Filter Down the Alerts
##This filter resets all instance with a new alert
$aa = Get-SCOMAlert -ResolutionState 0

  foreach ($UniqueAlert in $aa){
   write-verbose ($UniqueAlert.Name)
   if ( ($UniqueAlert.IsMonitorAlert) -eq $true  ){
    Write-Verbose "Alert is based on Monitor, resetting state."
    $Monitor = Get-SCOMMonitor -Id $UniqueAlert.MonitoringRuleId
    (Get-SCOMClassInstance -ID $UniqueAlert.MonitoringObjectId).ResetMonitoringState($Monitor) | Out-Null
   }
   else {
    Write-Verbose "Alert is based on Rule, resolving."
    $UniqueAlert | Resolve-SCOMAlert -Comment "Auto-Resolved by Cleanup Script"
   }
  }
