$wshell = New-Object -ComObject wscript.shell;

$i=1

While ($i -lt 100) {

$wshell.SendKeys("{F15}")
get-date
Start-Sleep -Seconds 100
}
