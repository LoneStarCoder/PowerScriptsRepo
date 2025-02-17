while ($true) {
 if (Get-Clipboard) {
  Write-host "Clip board has stuff, clearing in 3 seconds."
  start-sleep -Seconds 3
  set-clipboard -Value $null; write-host "cleared"
  }
}
