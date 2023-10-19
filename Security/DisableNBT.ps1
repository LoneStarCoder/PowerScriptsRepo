$adapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter 'IPEnabled = TRUE'
$result = 0
foreach ($adapter in $adapters) {
    if ($adapter.TcpipNetbiosOptions -ne 2) {
        $result++
    }
}
$result
