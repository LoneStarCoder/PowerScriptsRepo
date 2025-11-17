# Define parameters
$Path = "C:\Windows\System32\LogFiles\SMTPSVC1"
$SearchString = "EHLO"
$Age = (Get-Date).AddDays(-7)

# Get log files modified within the last 7 days
$LogFiles = Get-ChildItem -Path $Path | Where-Object { $_.LastWriteTime -ge $Age }

# Initialize array
$parsedLogs = @()

foreach ($logFile in $LogFiles) {
    # Read log content
    $logContent = Get-Content $logFile.FullName

    # Extract header fields
    $fieldsLine = ($logContent | Where-Object { $_ -like "#Fields:*" })
    $fields = $fieldsLine -replace "#Fields:\s*", "" -split "\s+"

    # Filter rows containing the search string and exclude unwanted entries
    $dataRows = $logContent | Where-Object { $_ -match $SearchString -and $_ -notmatch "OutboundConnectionCommand" }

    # Parse rows into objects (first 7 columns only)
    $parsedLogs += $dataRows | ForEach-Object {
        $values = $_ -split "\s+", $fields.Count
        [PSCustomObject]@{
            $fields[0] = $values[0]
            $fields[1] = $values[1]
            $fields[2] = $values[2]
            $fields[3] = $values[3]
            $fields[4] = $values[4]
            $fields[5] = $values[5]
            $fields[6] = $values[6]
        }
    }
}

# Output unique IP and username pairs
$parsedLogs | Select-Object -Unique c-ip, cs-username | Sort-Object c-ip
