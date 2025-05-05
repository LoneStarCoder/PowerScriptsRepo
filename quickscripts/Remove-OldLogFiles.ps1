$Logs = Get-ChildItem -Path C:\* -Include *.log  -Recurse
$d = (get-date).AddDays(-120)
$logs |  ? {$_.LastWriteTime -le $d} | Remove-Item
