#Query Windows Firewall Log
$Path = "C:\windows\system32\LogFiles\Firewall\pfirewall.log"
$Path = "C:\windows\system32\LogFiles\Firewall\pfirewall.log.old"
$fwlogcontents = Get-Content -Path $Path | Select-String "drop" | Select-String "RECEIVE" | Select-String -Pattern "224.0.0.251|239.255.255.250|224.0.0.252|255.255.255.255" -NotMatch
$fwlogcontents = Get-Content -Path $Path | Select-String "drop" | Select-String "send" | Select-String -Pattern "224.0.0.251|239.255.255.250|224.0.0.252|255.255.255.255" -NotMatch
$fwlogcontentswithcommas = $fwlogcontents -replace " ",","
#$fwlogcontentswithcommasClean = $fwlogcontentswithcommas.Split('`n') | Select -skip 11
$fwlogcontentswithcommasClean = $fwlogcontentswithcommas.Split('`n')

$fw = @()
$i=0
foreach ($line in $fwlogcontentswithcommasClean) {
 $i++
 write-host "Processed Line $i"
 $splitline = $line.Split(",")
 $obj = new-object psobject
 $obj | add-member -name Date -type noteproperty -value $splitline[0]
 $obj | add-member -name Time -type noteproperty -value $splitline[1]
 $obj | add-member -name Action -type noteproperty -value $splitline[2]
 $obj | add-member -name Protocol -type noteproperty -value $splitline[3]
 $obj | add-member -name srcIP -type noteproperty -value $splitline[4]
 $obj | add-member -name dstIP -type noteproperty -value $splitline[5]
 $obj | add-member -name srcPort -type noteproperty -value $splitline[6]
 $obj | add-member -name dstPort -type noteproperty -value $splitline[7]
 $obj | add-member -name size -type noteproperty -value $splitline[8]
 $obj | add-member -name tcpflags -type noteproperty -value $splitline[9]
 $obj | add-member -name tcpsyn -type noteproperty -value $splitline[10]
 $obj | add-member -name tcpack -type noteproperty -value $splitline[11]
 $obj | add-member -name tcpwin -type noteproperty -value $splitline[12]
 $obj | add-member -name icmptype -type noteproperty -value $splitline[13]
 $obj | add-member -name icmpcode -type noteproperty -value $splitline[14]
 $obj | add-member -name info -type noteproperty -value $splitline[15]
 $obj | add-member -name path -type noteproperty -value $splitline[16]
 $obj | add-member -name pid -type noteproperty -value $splitline[17]
 $fw += $obj

}

<#NOTES
224.0.0.251 with port 5353 is multicast DNS
239.255.255.250 with port 1900 is SSDP or UPNP - this is on, on many home networks, but we probably want it off
Port 137 is file and print sharing



$fw | ft *
$fw | ? {$_.DstIP -ne "192.168.2.255"} | Group-Object srcIP, dstIP, dstPort | Select Count, Name | Sort-Object Count -Descending
$fw | ? {$_.Action -eq 'drop' -and $_.path -eq 'RECEIVE' -and $_.srcIP -notlike "192.168.*" } | ft *
$fw | ? {$_.path -eq 'RECEIVE' -and $_.srcIP -notlike "192.168.1.*" } | ft *


$VPNAddress = '10.101.161.57'
$fw | ? {$_.Action -eq 'drop' -and $_.path -eq 'RECEIVE' -and $_.dstIP -eq '10.101.161.57' } | ft *

#>
