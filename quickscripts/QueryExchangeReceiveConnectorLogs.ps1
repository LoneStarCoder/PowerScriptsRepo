# Define the log file path
$path = "C:\Program Files\Microsoft\Exchange Server\V15\TransportRoles\Logs\FrontEnd\ProtocolLog\SmtpReceive"
$age = (get-date).AddDays(-3)
$Files = Get-ChildItem -Path $path | ? {$_.LastWriteTime -ge $age}
#$Files.Count

#$files | select -First 1 | fl *

foreach ($File in $Files) {

    $logFile = $File.FullName

    # Read all lines from the log file
    $lines = Get-Content -Path $logFile

    # Extract the header fields from the #Fields line
    $fieldsLine = ($lines | Where-Object { $_ -like "#Fields:*" })
    $fields = $fieldsLine -replace "#Fields:\s*", "" -split ","

    # Filter out comment lines and keep only data lines
    $dataLines = $lines | Where-Object { $_ -notmatch "^#" -and $_ -match "\S" }

    # Parse each line into an object
    $parsedLogs = foreach ($line in $dataLines) {
        $columns = $line -split ",(?=(?:[^""]*""[^""]*"")*[^""]*$)"  # Handles quoted commas
        $obj = [ordered]@{}
        for ($i = 0; $i -lt $fields.Count; $i++) {
            $obj[$fields[$i]] = $columns[$i]
        }
        [PSCustomObject]$obj
    }

}


# Output the array of parsed log entries
$parsedLogs
$parsedLogs | ? {$_.data -like "*EHLO*"} | Select -Unique data


# Example: Export to CSV if needed
# $parsedLogs | Export-Csv -Path "C:\Path\To\ParsedLogs.csv" -NoTypeInformation
