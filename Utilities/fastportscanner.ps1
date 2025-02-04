# Settings
$target       = "localhost"
$ports        = 1..10000
$totalPorts   = $ports.Count
$maxThreads   = 100  # Maximum number of concurrent runspaces
$timeout      = 50   # Timeout in milliseconds for each connection attempt

# Create a runspace pool
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $maxThreads)
$runspacePool.Open()

# Prepare a collection for runspace jobs and a thread-safe collection for results
$runspaceJobs = New-Object System.Collections.ArrayList
$results      = [System.Collections.Concurrent.ConcurrentBag[string]]::new()
$i            = 0

# Function: Create a script block that performs the port scan for a given port
$scriptBlock = {
    param($target, $port, $timeout)
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $result = $tcp.BeginConnect($target, $port, $null, $null)
        if ($result.AsyncWaitHandle.WaitOne($timeout)) {
            return "Port $port open"
        }
    }
    catch {
        # Handle any exception silently
    }
    finally {
        $tcp.Close()
    }
    return $null
}

# Create runspaces for each port
foreach ($port in $ports) {
    $i++
    # Update progress for submission of tasks
    Write-Progress -Activity "Scanning Ports" `
                   -Status "Queuing port $port ($i of $totalPorts)" `
                   -PercentComplete (($i / $totalPorts) * 100)

    $psInstance = [powershell]::Create()
    $psInstance.RunspacePool = $runspacePool
    $psInstance.AddScript($scriptBlock).AddArgument($target).AddArgument($port).AddArgument($timeout) | Out-Null

    # Begin asynchronous invocation
    $asyncResult = $psInstance.BeginInvoke()

    # Store job info (the PowerShell instance and its async handle)
    $runspaceJobs.Add(@{
        PowerShell = $psInstance
        AsyncResult = $asyncResult
    }) | Out-Null
}

# Retrieve results as runspaces complete
foreach ($job in $runspaceJobs) {
    $psInstance  = $job.PowerShell
    $asyncResult = $job.AsyncResult

    # End the asynchronous invocation, which returns the result (if any)
    $result = $psInstance.EndInvoke($asyncResult)
    if ($result -and $result.Trim()) {
        $results.Add($result)
    }
    $psInstance.Dispose()
}

# Clean up the runspace pool
$runspacePool.Close()
$runspacePool.Dispose()

# Output the open ports
$results | Sort-Object
