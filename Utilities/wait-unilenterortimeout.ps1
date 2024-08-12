function wait-unilenterortimeout  {
    param(
        [int]$seconds = 30
    )   
    $endTime = (Get-Date).AddSeconds($seconds)

    Write-Host "Press Enter to continue immediately or wait $seconds seconds."

    while ((Get-Date) -lt $endTime) {
        if ([console]::KeyAvailable) {
            $key = [console]::ReadKey($true)
            if ($key.Key -eq 'Enter') {
                break
            }
        }
        Start-Sleep -Milliseconds 1000  # Short sleep to reduce CPU usage
    }

    #Write-Host "Continuing script..."
}

wait-unilenterortimeout
