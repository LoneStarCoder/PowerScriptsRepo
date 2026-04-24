<#
.SYNOPSIS
    Scans one or more IP ranges for open TCP ports and exports the results to CSV.

.DESCRIPTION
    Scan-Network.ps1 is a high-performance, multi-threaded TCP port scanner written in PowerShell.
    It uses a runspace pool to test TCP connectivity in parallel so large subnet and multi-port
    scans complete much faster than a sequential approach.

    The script accepts individual IP addresses, arbitrary IPv4 CIDR ranges, or a 3-octet prefix
    such as 10.101.160. It generates the target IP list, tests the requested ports, and writes
    open-port findings to a CSV file.

    Hostname resolution is optional. When -ResolveHost is used, the script resolves names only for
    IP addresses that actually have at least one open port. To keep performance high, each IP is
    resolved at most once and the value is cached for reuse across additional open ports.

    Ping checks are also optional. When -TestPing is used, the script sends one ICMP echo request
    to each target IP and caches the result so the response state can be included in the output and
    final summary without repeating the check.

    The output file is initialized at the start of the scan with a CSV header unless -Append is
    used. If no open ports are found, the CSV still exists and contains the header row so
    downstream tools can still import it. Results can also be returned to the pipeline with
    -PassThru, and CSV output can be disabled entirely with -NoCsv.

.PARAMETER Subnets
    One or more target networks or IP addresses to scan.

    Supported formats:
    - A single IP address such as 10.101.160.15
    - Any IPv4 CIDR network such as 10.101.160.0/24 or 10.101.160.128/25
    - A 3-octet prefix such as 10.101.160

    For 3-octet prefixes, the script scans host addresses .1 through .254.
    For CIDR ranges, the script automatically expands the network into individual IPv4 addresses.

.PARAMETER Ports
    One or more TCP ports to test on each target IP address.

    The default ports are 80 and 443. You can pass a comma-separated list, a range, or any
    expression that resolves to an integer array.

.PARAMETER PortSet
    Adds a built-in named port preset to the scan.

    Presets:
    - Custom: uses only the ports passed to -Ports
    - Web: 80,443,8080,8443
    - Windows: 135,139,445,3389,5985,5986
    - Admin: 22,3389,5985,5986
    - Common: 22,53,80,135,139,443,445,3389,5985,5986,8080,8443

    If both -PortSet and -Ports are supplied, the script merges them into one unique port list.

.PARAMETER MaxThreads
    The maximum number of concurrent runspace threads used for connection attempts.

    Higher values can improve scan speed, but they also increase CPU usage, socket usage, and the
    chance of overwhelming slower networks or endpoints. The default is 100.

.PARAMETER Timeout
    The TCP connect timeout in milliseconds for each port test.

    Lower values are faster but may miss slower or higher-latency systems. Higher values are more
    reliable across routed networks, VPNs, or congested links, but will increase total scan time.
    The default is 50 milliseconds.

.PARAMETER OutputFile
    The path to the CSV file that will receive the scan results.

    The CSV contains these columns:
    - IP
    - HostName
    - Port
    - Status
    - Timestamp

.PARAMETER ResolveHost
    Resolves IP addresses to hostnames, but only for targets where at least one requested port is
    found open.

.PARAMETER TestPing
    Sends one ICMP echo request to each target IP and records whether the host responded.

    Ping results are cached per IP. When enabled, output rows include a PingStatus value of
    Success or NoResponse. When disabled, PingStatus is N/A.

.PARAMETER Append
    Appends results to an existing CSV file instead of overwriting it.

.PARAMETER NoCsv
    Disables CSV output entirely.

.PARAMETER PassThru
    Writes result objects to the pipeline in addition to any CSV output.

.PARAMETER Quiet
    Suppresses most informational console messages during the scan.

.PARAMETER SummaryOnly
    Suppresses per-hit console output and progress updates and shows only the final summary.

.PARAMETER ErrorLogFile
    Writes non-fatal scan and hostname-resolution errors to a log file.

.INPUTS
    None. You cannot pipe objects directly to this script.

.OUTPUTS
    PSCustomObject when -PassThru is used; otherwise none.

.NOTES
    Author: Brody Kilpatrick
    Version: 3.0

.EXAMPLE
    .\Scan-Network.ps1 -Subnets '10.101.160.0/24'

    Scans a single /24 network using the default ports 80 and 443.

.EXAMPLE
    .\Scan-Network.ps1 -Subnets '10.101.160.128/25' -PortSet Web

    Scans an arbitrary CIDR block using the built-in web port preset.

.EXAMPLE
    .\Scan-Network.ps1 -Subnets '10.101.160.10','10.101.160.11' -PortSet Windows -ResolveHost

    Scans specific Windows hosts, includes Windows-related ports, and resolves hostnames for hits.

.EXAMPLE
    .\Scan-Network.ps1 -Subnets '10.101.160.0/24' -Ports 80,443 -TestPing

    Scans web ports and records whether each responding host also answered ICMP ping.

.EXAMPLE
    .\Scan-Network.ps1 -Subnets '10.101.160','10.101.161.0/24' -Ports 22,443 -PassThru -NoCsv

    Scans two target ranges, skips CSV creation, and emits result objects to the pipeline.

.EXAMPLE
    .\Scan-Network.ps1 -Subnets '10.101.0.0/16' -PortSet Admin -Append -OutputFile '.\admin-scan.csv'

    Appends administrative service findings to an existing report file.

.EXAMPLE
    .\Scan-Network.ps1 -Subnets '10.101.160.0/24' -PortSet Web -SummaryOnly

    Runs the scan without per-hit console messages and prints only the final summary.

.EXAMPLE
    .\Scan-Network.ps1 -Subnets '10.101.160.0/24' -ResolveHost -ErrorLogFile '.\scan-errors.log'

    Logs recoverable errors, such as reverse DNS lookup failures, to a separate file.

.EXAMPLE
    Get-Help .\Scan-Network.ps1 -Full

    Displays the full comment-based help for the script.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Subnets,

    [Parameter(Position = 1)]
    [ValidateRange(1, 65535)]
    [int[]]$Ports = @(80, 443),

    [ValidateSet('Custom', 'Web', 'Windows', 'Admin', 'Common')]
    [string]$PortSet = 'Custom',

    [ValidateRange(1, 4096)]
    [int]$MaxThreads = 100,

    [ValidateRange(1, 30000)]
    [int]$Timeout = 50,

    [string]$OutputFile = "$PSScriptRoot\ScanResults.csv",

    [switch]$ResolveHost,

    [switch]$TestPing,

    [switch]$Append,

    [switch]$NoCsv,

    [switch]$PassThru,

    [switch]$Quiet,

    [switch]$SummaryOnly,

    [string]$ErrorLogFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Status {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )

    if (-not $Quiet) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Write-ScanError {
    param(
        [string]$Message
    )

    if ([string]::IsNullOrWhiteSpace($ErrorLogFile)) {
        return
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "[$timestamp] $Message" | Add-Content -LiteralPath $ErrorLogFile
}

function ConvertTo-IPv4UInt32 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress
    )

    $parsed = [System.Net.IPAddress]::Parse($IPAddress)
    if ($parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        throw "Only IPv4 addresses are supported: $IPAddress"
    }

    $bytes = $parsed.GetAddressBytes()
    [Array]::Reverse($bytes)
    return [BitConverter]::ToUInt32($bytes, 0)
}

function ConvertFrom-IPv4UInt32 {
    param(
        [Parameter(Mandatory = $true)]
        [uint32]$Value
    )

    $bytes = [BitConverter]::GetBytes($Value)
    [Array]::Reverse($bytes)
    return ([System.Net.IPAddress]::new($bytes)).ToString()
}

function Get-PortPreset {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    switch ($Name) {
        'Web' { return @(80, 443, 8080, 8443) }
        'Windows' { return @(135, 139, 445, 3389, 5985, 5986) }
        'Admin' { return @(22, 3389, 5985, 5986) }
        'Common' { return @(22, 53, 80, 135, 139, 443, 445, 3389, 5985, 5986, 8080, 8443) }
        default { return @() }
    }
}

function Get-TargetIPs {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Entries
    )

    $targets = New-Object System.Collections.Generic.List[string]
    $seen = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($entry in $Entries) {
        $trimmed = $entry.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            throw "Target entries cannot be empty."
        }

        if ($trimmed -match '^(?<prefix>\d{1,3}(?:\.\d{1,3}){2})$') {
            $basePrefix = $Matches.prefix
            foreach ($host in 1..254) {
                $ip = "$basePrefix.$host"
                if ($seen.Add($ip)) {
                    $targets.Add($ip)
                }
            }
            continue
        }

        if ($trimmed -match '^(?<ip>\d{1,3}(?:\.\d{1,3}){3})/(?<mask>\d{1,2})$') {
            $ipString = $Matches.ip
            $prefixLength = [int]$Matches.mask

            if ($prefixLength -lt 0 -or $prefixLength -gt 32) {
                throw "Invalid CIDR mask '$prefixLength' in '$trimmed'."
            }

            $networkValue = ConvertTo-IPv4UInt32 -IPAddress $ipString
            $hostBits = 32 - $prefixLength
            $blockSize = [math]::Pow(2, $hostBits)
            $usableCount = if ($prefixLength -ge 31) { [uint64]$blockSize } else { [uint64]([math]::Max($blockSize - 2, 0)) }

            if ($usableCount -gt 1048576) {
                throw "CIDR range '$trimmed' expands to $usableCount addresses, which is too large for this script."
            }

            $maskValue = if ($prefixLength -eq 0) { [uint32]0 } else { [uint32]::MaxValue -shl $hostBits }
            $startNetwork = $networkValue -band $maskValue
            $startValue = if ($prefixLength -ge 31) { $startNetwork } else { $startNetwork + 1 }
            $endValue = if ($prefixLength -ge 31) { $startNetwork + [uint32]($blockSize - 1) } else { $startNetwork + [uint32]($blockSize - 2) }

            for ($current = [uint64]$startValue; $current -le [uint64]$endValue; $current++) {
                $ip = ConvertFrom-IPv4UInt32 -Value ([uint32]$current)
                if ($seen.Add($ip)) {
                    $targets.Add($ip)
                }
            }
            continue
        }

        try {
            $parsed = [System.Net.IPAddress]::Parse($trimmed)
            if ($parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
                throw "Only IPv4 addresses are supported."
            }

            $ip = $parsed.ToString()
            if ($seen.Add($ip)) {
                $targets.Add($ip)
            }
        }
        catch {
            throw "Unsupported target format: '$trimmed'. Use a single IPv4 address, CIDR, or a 3-octet prefix."
        }
    }

    return ,$targets
}

function Initialize-OutputFile {
    param(
        [string]$Path,
        [switch]$AppendMode,
        [switch]$DisableCsv
    )

    if ($DisableCsv) {
        return
    }

    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    if (-not $AppendMode -or -not (Test-Path -LiteralPath $Path)) {
        '"IP","HostName","PingStatus","Port","Status","Timestamp"' | Set-Content -LiteralPath $Path
    }
}

function Initialize-LogFile {
    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    '' | Set-Content -LiteralPath $Path
}

function Flush-ResultBuffer {
    param(
        [System.Collections.Generic.List[object]]$Buffer,
        [string]$Path,
        [switch]$DisableCsv
    )

    if ($DisableCsv -or $Buffer.Count -eq 0) {
        $Buffer.Clear()
        return
    }

    $csvLines = $Buffer | ConvertTo-Csv -NoTypeInformation
    if ($csvLines.Count -gt 1) {
        $csvLines[1..($csvLines.Count - 1)] | Add-Content -LiteralPath $Path
    }

    $Buffer.Clear()
}

function Get-ResolvedHostName {
    param(
        [string]$IpAddress,
        [System.Collections.Concurrent.ConcurrentDictionary[string, string]]$Cache,
        [ref]$ResolutionFailures
    )

    return $Cache.GetOrAdd($IpAddress, {
        param($address)

        try {
            $entry = [System.Net.Dns]::GetHostEntry($address)
            if ([string]::IsNullOrWhiteSpace($entry.HostName)) {
                $ResolutionFailures.Value++
                Write-ScanError -Message "Reverse DNS returned no hostname for $address."
                return 'Unknown'
            }

            return $entry.HostName
        }
        catch {
            $ResolutionFailures.Value++
            Write-ScanError -Message "Reverse DNS lookup failed for $address. $($_.Exception.Message)"
            return 'Unknown'
        }
    })
}

function Test-PingStatus {
    param(
        [string]$IpAddress,
        [int]$PingTimeout,
        [System.Collections.Concurrent.ConcurrentDictionary[string, string]]$Cache,
        [ref]$PingFailures
    )

    return $Cache.GetOrAdd($IpAddress, {
        param($address)

        $pinger = [System.Net.NetworkInformation.Ping]::new()
        try {
            $reply = $pinger.Send($address, $PingTimeout)
            if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                return 'Success'
            }

            return 'NoResponse'
        }
        catch {
            $PingFailures.Value++
            Write-ScanError -Message "Ping test failed for $address. $($_.Exception.Message)"
            return 'NoResponse'
        }
        finally {
            $pinger.Dispose()
        }
    })
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$hostNameCache = [System.Collections.Concurrent.ConcurrentDictionary[string, string]]::new()
$pingStatusCache = [System.Collections.Concurrent.ConcurrentDictionary[string, string]]::new()
$resultBuffer = [System.Collections.Generic.List[object]]::new()
$runspaceJobs = New-Object System.Collections.ArrayList
$runspacePool = $null
$ipList = $null
$effectivePorts = $null
$totalTasks = 0
$resultsWritten = 0
$resolutionFailures = 0
$pingFailureCount = 0
$pingResponsiveHosts = 0
$bufferFlushSize = 200
$portsExplicitlyProvided = $PSBoundParameters.ContainsKey('Ports')

try {
    $basePorts = if ($PortSet -ne 'Custom' -and -not $portsExplicitlyProvided) { @() } else { $Ports }
    [int[]]$effectivePorts = @($basePorts + (Get-PortPreset -Name $PortSet) | Sort-Object -Unique)
    if (-not $effectivePorts -or $effectivePorts.Count -eq 0) {
        throw 'At least one TCP port must be supplied.'
    }

    $ipList = Get-TargetIPs -Entries $Subnets
    if ($ipList.Count -eq 0) {
        throw 'No valid targets were generated from the supplied input.'
    }

    Initialize-OutputFile -Path $OutputFile -AppendMode:$Append -DisableCsv:$NoCsv
    Initialize-LogFile -Path $ErrorLogFile

    $totalTasks = $ipList.Count * $effectivePorts.Count
    $counter = 0
    $openPortCount = 0
    $effectivePingTimeout = [Math]::Max($Timeout, 100)

    if ($TestPing) {
        Write-Status -Message "Testing ICMP reachability for $($ipList.Count) target(s)..." -Color Yellow
        foreach ($ip in $ipList) {
            $pingStatus = Test-PingStatus -IpAddress $ip -PingTimeout $effectivePingTimeout -Cache $pingStatusCache -PingFailures ([ref]$script:pingFailureCount)
            if ($pingStatus -eq 'Success') {
                $pingResponsiveHosts++
            }
        }
    }

    Write-Status -Message "Targets: $($ipList.Count) IPs | Ports: $($effectivePorts.Count) | Threads: $MaxThreads | Resolve DNS: $($ResolveHost.IsPresent) | Test Ping: $($TestPing.IsPresent)" -Color Cyan

    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
    $runspacePool.Open()

    $scriptBlock = {
        param($ip, $port, $timeout)

        $tcp = New-Object System.Net.Sockets.TcpClient
        try {
            $result = $tcp.BeginConnect($ip, $port, $null, $null)
            if ($result.AsyncWaitHandle.WaitOne($timeout)) {
                $tcp.EndConnect($result)
                return [PSCustomObject]@{
                    IP        = $ip
                    Port      = $port
                    Status    = 'Open'
                    Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                }
            }
        }
        catch {
            return [PSCustomObject]@{
                IP        = $ip
                Port      = $port
                Error     = $_.Exception.Message
                Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            }
        }
        finally {
            $tcp.Close()
        }

        return $null
    }

    function Publish-ScanResult {
        param(
            [pscustomobject]$Result
        )

        if (-not $Result) {
            return
        }

        if ($Result.PSObject.Properties.Name -contains 'Error') {
            Write-ScanError -Message "TCP connect failed for $($Result.IP):$($Result.Port). $($Result.Error)"
            return
        }

        $hostName = 'N/A'
        if ($ResolveHost) {
            $hostName = Get-ResolvedHostName -IpAddress $Result.IP -Cache $hostNameCache -ResolutionFailures ([ref]$script:resolutionFailures)
        }

        $pingStatus = 'N/A'
        if ($TestPing) {
            $pingStatus = Test-PingStatus -IpAddress $Result.IP -PingTimeout $effectivePingTimeout -Cache $pingStatusCache -PingFailures ([ref]$script:pingFailureCount)
        }

        $outputRow = [PSCustomObject]@{
            IP        = $Result.IP
            HostName  = $hostName
            PingStatus = $pingStatus
            Port      = $Result.Port
            Status    = $Result.Status
            Timestamp = $Result.Timestamp
        }

        $script:openPortCount++

        if (-not $Quiet -and -not $SummaryOnly) {
            Write-Host "[+] FOUND: $($outputRow.IP) ($($outputRow.HostName)):$($outputRow.Port)" -ForegroundColor Green
        }

        if ($PassThru) {
            Write-Output $outputRow
        }

        $resultBuffer.Add($outputRow)
        if ($resultBuffer.Count -ge $bufferFlushSize) {
            Flush-ResultBuffer -Buffer $resultBuffer -Path $OutputFile -DisableCsv:$NoCsv
        }
    }

    foreach ($ip in $ipList) {
        foreach ($port in $effectivePorts) {
            $counter++

            while ($runspaceJobs.Count -ge ($MaxThreads * 2)) {
                $finished = $runspaceJobs | Where-Object { $_.Result.IsCompleted }
                foreach ($job in $finished) {
                    $res = $job.Instance.EndInvoke($job.Result)
                    Publish-ScanResult -Result $res
                    $job.Instance.Dispose()
                    [void]$runspaceJobs.Remove($job)
                }
                Start-Sleep -Milliseconds 20
            }

            $ps = [powershell]::Create().AddScript($scriptBlock).AddArgument($ip).AddArgument($port).AddArgument($Timeout)
            $ps.RunspacePool = $runspacePool
            [void]$runspaceJobs.Add(@{
                Instance = $ps
                Result   = $ps.BeginInvoke()
            })

            if (-not $Quiet -and -not $SummaryOnly -and $counter % 100 -eq 0) {
                Write-Progress -Activity 'Scanning Network' -Status "Testing $ip" -PercentComplete (($counter / $totalTasks) * 100)
            }
        }
    }

    Write-Status -Message 'Wrapping up remaining tasks...' -Color Yellow
    while ($runspaceJobs.Count -gt 0) {
        $finished = $runspaceJobs | Where-Object { $_.Result.IsCompleted }
        foreach ($job in $finished) {
            $res = $job.Instance.EndInvoke($job.Result)
            Publish-ScanResult -Result $res
            $job.Instance.Dispose()
            [void]$runspaceJobs.Remove($job)
        }
        Start-Sleep -Milliseconds 50
    }

    Flush-ResultBuffer -Buffer $resultBuffer -Path $OutputFile -DisableCsv:$NoCsv
    $resultsWritten = $openPortCount
}
finally {
    if ($null -ne $runspacePool) {
        $runspacePool.Close()
        $runspacePool.Dispose()
    }

    $stopwatch.Stop()

    if (-not $NoCsv -and $resultsWritten -eq 0) {
        Write-Status -Message "No open ports found. Header-only CSV saved to $OutputFile" -Color Yellow
    }

    $summary = [PSCustomObject]@{
        TargetCount         = if ($null -ne $ipList) { $ipList.Count } else { 0 }
        PortCount           = if ($null -ne $effectivePorts) { $effectivePorts.Count } else { 0 }
        ConnectionAttempts  = if ($null -ne $totalTasks) { $totalTasks } else { 0 }
        OpenPortCount       = $resultsWritten
        PingTestEnabled     = $TestPing.IsPresent
        PingResponsiveHosts = $pingResponsiveHosts
        PingFailures        = $pingFailureCount
        HostResolutionFails = $resolutionFailures
        ElapsedSeconds      = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
        CsvOutputEnabled    = (-not $NoCsv)
        OutputFile          = if (-not $NoCsv) { $OutputFile } else { $null }
    }

    if (-not $Quiet) {
        Write-Host ''
        Write-Host 'Scan Summary' -ForegroundColor Cyan
        Write-Host "Targets scanned      : $($summary.TargetCount)"
        Write-Host "Ports per host       : $($summary.PortCount)"
        Write-Host "Connection attempts  : $($summary.ConnectionAttempts)"
        Write-Host "Open ports found     : $($summary.OpenPortCount)"
        Write-Host "Ping enabled         : $($summary.PingTestEnabled)"
        if ($summary.PingTestEnabled) {
            Write-Host "Ping responders      : $($summary.PingResponsiveHosts)"
            Write-Host "Ping failures        : $($summary.PingFailures)"
        }
        Write-Host "DNS resolution fails : $($summary.HostResolutionFails)"
        Write-Host "Elapsed seconds      : $($summary.ElapsedSeconds)"
        if ($summary.CsvOutputEnabled) {
            Write-Host "CSV output           : $($summary.OutputFile)"
        }
        else {
            Write-Host 'CSV output           : Disabled'
        }
        if (-not [string]::IsNullOrWhiteSpace($ErrorLogFile)) {
            Write-Host "Error log            : $ErrorLogFile"
        }
    }
}
