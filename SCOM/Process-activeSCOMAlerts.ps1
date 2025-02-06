####Adjust for your own environment###
####Adjust for your own environment###
####Adjust for your own environment###
####Adjust for your own environment###
####Adjust for your own environment###
# Import the OperationsManager module
Import-Module OperationsManager

# Connect to the SCOM Management Group
New-SCOMManagementGroupConnection -ComputerName "server"

# Define a function to get resolution states and store them in a variable
function Get-SCOMResolutionStates {
    $global:resolutionStates = Get-SCOMAlertResolutionState | ? {$_.ResolutionState -in 0, 100, 110, 112, 113, 114, 115, 120, 122, 123, 127, 130, 131, 141, 249, 255} | Select-Object Name, ResolutionState
    #$global:resolutionStates
}

# Retrieve new SCOM alerts and process them
function Retrieve-And-Process-SCOMAlerts {
    # Retrieve SCOM alerts with a resolution state of 'New' (ID: 0)
    $newAlerts = Get-SCOMAlert -ResolutionState 0 -Severity 1,2 | ? {$_.Name -notin "Windows Server 2016 Print Server Printer State Alert", "Some other alert I don't want to process"}

    # Display each alert's Name, Description, and whether it is from a Rule or Monitor
    foreach ($alert in $newAlerts) {
        $alertType = if ($alert.IsMonitorAlert) { "Monitor" } else { "Rule" }
        # Validate user input and set the resolution state of each alert
        # Display list of resolution states for user choice
        Write-Output "Resolution States:"
        $global:resolutionStates | ForEach-Object { Write-Output "$($_.ResolutionState) - $($_.Name)" }
        Write-Host "Alert Name: $($alert.Name)" -ForegroundColor Green
        Write-Host "Full Name: $($alert.MonitoringObjectFullName)" -ForegroundColor DarkYellow
        Write-Host "-"
        Write-Host "Description: $($alert.Description)"
        Write-Host "Type: $alertType" -ForegroundColor Cyan
        # Ask user to select a resolution state ID
        $userSelectedStateId = Read-Host "Enter the ID of the resolution state to assign to the alerts"
        if ($global:resolutionStates.ResolutionState -eq $userSelectedStateId -and $alertType -eq "Rule") {
            $alert | Set-SCOMAlert -ResolutionState $userSelectedStateId
            Write-Output "Alert `"$($alert.Name)`" resolution state updated to $userSelectedStateId"
        } elseif ($global:resolutionStates.ResolutionState -eq $userSelectedStateId -and $alertType -eq "Monitor") { #We need to handle Resolutions different if Monitor.
            if ($userSelectedStateId -eq 255){
                write-host "Resetting Monitor"
                $alert.MonitoringObjectId
                (Get-SCOMClassInstance -Id ($alert.MonitoringObjectId)).ResetMonitoringState() | Out-Null
            } else {
                $alert | Set-SCOMAlert -ResolutionState $userSelectedStateId
                Write-Output "Alert `"$($alert.Name)`" resolution state updated to $userSelectedStateId"
            }
        }
        else { #Not going to process Rule.
            Write-Output "Invalid resolution state ID. No changes made to alert `"$($alert.Name)`"."
        }
    }
}

Get-SCOMResolutionStates
# Continuous loop to process the alerts every minute
while ($true) {
    Retrieve-And-Process-SCOMAlerts
   # Sleep for 1 minute
   Clear-Host
   write-host (Get-Date) -ForegroundColor DarkGray
   write-host "Sleeping for 60 Seconds." -ForegroundColor Cyan
   Start-Sleep -Seconds 60
}
