<#
.SYNOPSIS
Keeps the session active by simulating a key press at a specified interval.

.DESCRIPTION
The Start-KeepAlive function prevents the system from going into a sleep state or activating the screensaver by simulating the pressing of the F15 key on the keyboard. It does this repeatedly for a specified number of times and intervals.

.PARAMETER Times
The number of times to simulate the key press. Defaults to 100 if not specified.

.PARAMETER IntervalSeconds
The time interval in seconds between each simulated key press. Defaults to 100 seconds if not specified.

.EXAMPLE
Start-KeepAlive -Times 50 -IntervalSeconds 120

This command simulates an F15 key press 50 times with a 120-second interval between each press.

.NOTES
This function uses the COM object wscript.shell to send the keystrokes. Ensure that the PowerShell window remains in focus for SendKeys to work correctly. The total runtime is displayed and updated after each interval.
#>
function Start-KeepAlive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [int]$Times = 100,

        [Parameter(Mandatory=$false)]
        [int]$Intervalseconds = 100
    )

    $wshell = New-Object -ComObject wscript.shell;
    [int]$TotalTime =  $Times * $Intervalseconds
    Write-Host (Get-Date) -ForegroundColor Green
    Write-Host "Keeping Alive for $TotalTime Seconds" -ForegroundColor Yellow
    for ($i=1; $i -le $Times; $i++) {
        $wshell.SendKeys("{F15}")
        Start-Sleep -Seconds $Intervalseconds
        $TotalTime=$TotalTime-$Intervalseconds
        Write-Output "Time Left $TotalTime"
    }
}
