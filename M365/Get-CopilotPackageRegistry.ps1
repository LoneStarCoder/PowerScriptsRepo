<#
.SYNOPSIS
    Exports the Microsoft 365 Copilot package registry with full details for
    every package.

.DESCRIPTION
    Uses the Agent 365 Package Management API on Microsoft Graph v1.0:
        GET /copilot/admin/catalog/packages        list (paged)
        GET /copilot/admin/catalog/packages/{id}   full detail per package

    The detail endpoint builds its response from other services and
    intermittently returns 424 (Failed Dependency). Each failed request gets
    one quick retry; packages that still fail with a transient status are
    retried in sweep passes after a pause.

    Writes the raw list, the raw details and any remaining failures as JSON,
    and optionally a flattened CSV with one column per property returned.

.REQUIREMENTS
    - Windows PowerShell 5.1 or PowerShell 7+
    - Microsoft.Graph.Authentication module (v2+)
    - CopilotPackages.Read.All
    - Microsoft Agent 365 licensing in the tenant (required by the API)

.PARAMETER OutputDirectory
    Folder for the export files. Created if missing.

.PARAMETER AgentsOnly
    Return only packages that run in Copilot (agents). Without this switch
    the registry also includes Teams apps and Office add-ins.

.PARAMETER ExportCsv
    Also write a flattened CSV of the package details.

.PARAMETER SweepPasses
    How many times to go back over packages that failed with a transient
    error (424, 429, 500, 502, 503, 504). Default 3.

.PARAMETER SweepDelaySeconds
    Pause before each sweep pass. Default 60.

.EXAMPLE
    .\Get-CopilotPackageRegistry.ps1 -AgentsOnly -ExportCsv
#>
[CmdletBinding()]
param(
    [string]$OutputDirectory = '.\CopilotAgentRegistry',
    [switch]$AgentsOnly,
    [switch]$ExportCsv,
    [ValidateRange(0, 10)]
    [int]$SweepPasses = 4,
    [ValidateRange(0, 600)]
    [int]$SweepDelaySeconds = 5
)

$ErrorActionPreference = 'Stop'
Import-Module Microsoft.Graph.Authentication

$BaseUri   = 'https://graph.microsoft.com/v1.0/copilot/admin/catalog/packages'
$Stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
$Transient = 424, 429, 500, 502, 503, 504

# HTTP status code from an Invoke-MgGraphRequest error, or $null if none.
function Get-HttpStatus {
    param($ErrorRecord)
    if ($ErrorRecord.Exception.Response) { return [int]$ErrorRecord.Exception.Response.StatusCode }
    if ($ErrorRecord.Exception.Message -match 'success: (\d{3})') { return [int]$Matches[1] }
}

# Package detail with one quick retry for 424/500/502. The Graph SDK
# already retries 429/503/504 itself.
function Get-PackageDetail {
    param([string]$Id)
    # An empty id would silently turn the request into the list URL.
    if (-not $Id) { throw 'Package has no id.' }
    $Uri = '{0}/{1}' -f $BaseUri, [uri]::EscapeDataString($Id)
    try {
        Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
    }
    catch {
        if ((Get-HttpStatus $_) -notin 424, 500, 502) { throw }
        Start-Sleep -Seconds (2 + (Get-Random -Maximum 3))
        Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
    }
}

# Flatten a value into one CSV cell: string lists are joined, objects
# become compact JSON.
function ConvertTo-CsvCell {
    param($Value)
    if ($null -eq $Value -or $Value -is [string] -or $Value -is [ValueType]) { return $Value }
    $Items = @($Value)
    if (-not ($Items | Where-Object { $_ -isnot [string] -and $_ -isnot [ValueType] })) {
        return $Items -join '; '
    }
    ConvertTo-Json -InputObject $Value -Depth 20 -Compress
}

New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null

try {
    Connect-MgGraph -Scopes 'CopilotPackages.Read.All' -ContextScope Process -NoWelcome
    $Context = Get-MgContext
    Write-Host "Connected as $($Context.Account) (tenant $($Context.TenantId))"

    # 1. Package list, following @odata.nextLink paging.
    $Uri = $BaseUri
    if ($AgentsOnly) { $Uri += "?`$filter=supportedHosts/any(h:h eq 'Copilot')" }

    $Packages = @(
        while ($Uri) {
            $Page = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
            if ($Page.value) { $Page.value }
            $Uri = $Page.'@odata.nextLink'
        }
    )
    Write-Host "Found $($Packages.Count) packages."

    # 2. Full detail per package. Pass 0 is the first attempt; each sweep
    #    retries only the packages that failed with a transient status.
    $Details  = [System.Collections.Generic.List[object]]::new()
    $Failures = [System.Collections.Generic.List[object]]::new()
    $Pending  = @(
        foreach ($Package in $Packages) {
            [pscustomobject]@{
                id          = $Package.id
                displayName = $Package.displayName
                status      = $null
                error       = $null
                response    = $null
            }
        }
    )

    for ($Pass = 0; $Pass -le $SweepPasses -and $Pending.Count; $Pass++) {
        $Activity = 'Retrieving package details'
        if ($Pass) {
            $Activity = "Sweep $Pass of $SweepPasses"
            Write-Host "Transient failures: $($Pending.Count). $Activity in $SweepDelaySeconds seconds..."
            Start-Sleep -Seconds $SweepDelaySeconds
        }

        $i = 0
        $Total = $Pending.Count
        $Pending = @(
            foreach ($Item in $Pending) {
                $i++
                Write-Progress -Activity $Activity -Status "$i of ${Total}: $($Item.displayName)" `
                    -PercentComplete ($i / $Total * 100)
                try {
                    $Details.Add((Get-PackageDetail -Id $Item.id))
                }
                catch {
                    $Item.status   = Get-HttpStatus $_
                    $Item.error    = $_.Exception.Message
                    $Item.response = $_.ErrorDetails.Message   # Graph error body, incl. request-id
                    if ($Item.status -in $Transient) {
                        $Item   # retry in the next sweep
                    }
                    else {
                        Write-Warning "Failed to get package $($Item.id): $($Item.error)"
                        $Failures.Add($Item)
                    }
                }
            }
        )
        Write-Progress -Activity $Activity -Completed
    }
    foreach ($Item in $Pending) { $Failures.Add($Item) }

    # 3. Save output. -InputObject keeps 0- and 1-item results as JSON arrays.
    $ListPath     = Join-Path $OutputDirectory "CopilotPackageList-$Stamp.json"
    $DetailsPath  = Join-Path $OutputDirectory "CopilotPackageDetails-$Stamp.json"
    $FailuresPath = Join-Path $OutputDirectory "CopilotPackageFailures-$Stamp.json"
    $CsvPath      = Join-Path $OutputDirectory "CopilotPackageDetails-$Stamp.csv"

    ConvertTo-Json -InputObject $Packages -Depth 50 | Set-Content -Path $ListPath -Encoding UTF8
    ConvertTo-Json -InputObject $Details  -Depth 50 | Set-Content -Path $DetailsPath -Encoding UTF8

    if ($Failures.Count) {
        ConvertTo-Json -InputObject $Failures | Set-Content -Path $FailuresPath -Encoding UTF8
    }

    if ($ExportCsv) {
        # One column per property any package returned (the API returns many
        # undocumented ones, and not every package has the same set).
        # Key columns first, then the rest alphabetically.
        $Lead = 'id', 'displayName', 'type', 'publisher', 'platform', 'version', 'isBlocked',
                'availableTo', 'deployedTo', 'ownerId', 'createdDateTime',
                'lastModifiedDateTime', 'lastUsedDateTime', 'activeUsers', 'totalSessions'
        $Returned = @($Details | ForEach-Object { $_.PSObject.Properties.Name } |
            Where-Object { $_ -notlike '@odata.*' } | Sort-Object -Unique)
        $Columns = @($Lead | Where-Object { $_ -in $Returned }) +
                   @($Returned | Where-Object { $_ -notin $Lead })

        $Details |
            ForEach-Object {
                $Row = [ordered]@{}
                foreach ($Column in $Columns) { $Row[$Column] = ConvertTo-CsvCell $_.$Column }
                [pscustomobject]$Row
            } |
            Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    }

    Write-Host ''
    Write-Host "Packages found:    $($Packages.Count)"
    Write-Host "Details retrieved: $($Details.Count)"
    Write-Host "Failures:          $($Failures.Count)"
    Write-Host "Output folder:     $((Resolve-Path $OutputDirectory).Path)"
    if ($Failures.Count) { Write-Warning "See $FailuresPath for the packages that couldn't be retrieved." }

    $Details | Sort-Object displayName |
        Format-Table displayName, type, publisher, isBlocked, deployedTo, activeUsers, lastUsedDateTime -AutoSize
}
finally {
    if (Get-MgContext) { Disconnect-MgGraph | Out-Null }
}
