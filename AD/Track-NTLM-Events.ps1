# Track-NTLM-Events.ps1
param(
  [int]$Days = 7,
  [string]$OutputCsv = "C:\Temp\NTLM_Events.csv"
)

# Time window
$since = (Get-Date).AddDays(-$Days)

# NTLM Operational event IDs
$ids = @(8001,8002,8003,8004,4014,4024)

$filter = @{
  LogName   = 'Microsoft-Windows-NTLM/Operational'
  Id        = $ids
  StartTime = $since
}

$events = Get-WinEvent -FilterHashtable $filter -ErrorAction Stop |
ForEach-Object {
  $xml = [xml]$_.ToXml()

  # Build a name->value map for EventData
  $edata = @{}
  foreach ($d in $xml.Event.EventData.Data) {
    if ($d.Name) { $edata[$d.Name] = $d.'#text' }
  }

  # Extract known fields
  $workstation = if ($edata.ContainsKey('WorkstationName')) { $edata['WorkstationName'] } else { $null }
  $schannel    = if ($edata.ContainsKey('SChannelName')) { $edata['SChannelName'] } else { $null }
  $username    = if ($edata.ContainsKey('UserName')) { $edata['UserName'] } else { $null }
  $logComputer = $xml.Event.System.Computer

  [PSCustomObject]@{
    TimeCreated     = $_.TimeCreated
    EventId         = $_.Id
    Level           = $_.LevelDisplayName
    ProviderName    = $_.ProviderName
    LogComputer     = $logComputer
    WorkstationName = $workstation
    SChannelName    = $schannel
    UserName        = $username
    RecordId        = $_.RecordId
    Message         = ($_.Message -replace "`r?`n", ' ')
    RawXml          = $_.ToXml()
  }
}

# Ensure output folder exists
$dir = Split-Path $OutputCsv -Parent
if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }

$events | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Output "Exported $($events.Count) NTLM events since $since to $OutputCsv"
