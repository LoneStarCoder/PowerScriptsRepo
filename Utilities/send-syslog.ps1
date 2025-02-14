$SyslogServer = "192.168.0.1"  # Replace with your syslog server IP or hostname
$SyslogPort = 514  # Default UDP syslog port
$Message = "<13>Jan 12 12:34:56 HostName PowerShell: Test syslog message"

$UdpClient = New-Object System.Net.Sockets.UdpClient
$SyslogServerEP = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Parse($SyslogServer), $SyslogPort)
$MessageBytes = [System.Text.Encoding]::ASCII.GetBytes($Message)
$UdpClient.Send($MessageBytes, $MessageBytes.Length, $SyslogServerEP)
$UdpClient.Close()

Write-Output "Syslog message sent to $SyslogServer"
