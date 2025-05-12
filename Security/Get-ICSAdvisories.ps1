<#
.SYNOPSIS
    Displays recent CISA ICS advisories in a color‑coded console view.

.DESCRIPTION
    Downloads the Cybersecurity & Infrastructure Security Agency (CISA) Industrial
    Control Systems (ICS) advisories RSS feed, filters entries newer than the
    last **$DaysBack** days, extracts any CVSS‑v3 base score, maps the score to a
    four‑letter severity bucket (CRIT, HIGH, MEDI, LOW), and prints each advisory
    with colorised severity for quick triage.

.PARAMETER FeedUrl
    (String) The RSS feed URL.  Defaults to
    https://www.cisa.gov/cybersecurity-advisories/ics-advisories.xml.

.PARAMETER DaysBack
    (Int)  Look‑back window in days (default: 14).

.EXAMPLE
    PS> .\Get-ICSAdvisories.ps1
    Shows advisories published in the last 14 days.

.EXAMPLE
    PS> .\Get-ICSAdvisories.ps1 -DaysBack 30
    Shows the last 30 days of advisories.

.NOTES
    Author  : Brody Kilpatrick
    Updated : 12 May 2025
    Version : 1.1 – fixed ForegroundColor null issue & trimmed severity values.
#>

[string] $FeedUrl  = 'https://www.cisa.gov/cybersecurity-advisories/ics-advisories.xml'
[int]    $DaysBack = 30

function Get-IcsAdvisoryFeed {
    <#
    .SYNOPSIS
        Download and parse the CISA ICS advisories feed.

    .DESCRIPTION
        Retrieves the RSS feed from the provided URL, converts it to XML, and
        emits one custom object per advisory that is newer than the supplied
        cutoff date.

    .PARAMETER Url
        The RSS feed URL to query.

    .PARAMETER Cutoff
        A [datetime] value; advisories older than this are skipped.

    .OUTPUTS
        [pscustomobject] with the properties: Date, Advisory, Severity, CVSS,
        Title, Link.
    #>
    param(
        [Parameter(Mandatory)][string]   $Url,
        [Parameter(Mandatory)][datetime] $Cutoff
    )

    $xml = [xml](Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop).Content

    foreach ($item in $xml.rss.channel.item) {
        $dt = [datetime]$item.pubDate
        if ($dt -lt $Cutoff) { continue }

        $advisoryId = if ($item.title -match '(\w+-\d+-\d+-\d+)') { $Matches[1] }
        $cvssRaw    = if ($item.description -match 'CVSS.*?(\d+\.\d+)') { [decimal]$Matches[1] }

        $severity = switch ($cvssRaw) {
            { $_ -ge 9.0 }                 { 'CRIT' }
            { $_ -ge 7.0 -and $_ -lt 9.0 } { 'HIGH' }
            { $_ -ge 4.0 -and $_ -lt 7.0 } { 'MEDI' }
            default                        { 'LOW'  }
        }

        [pscustomobject]@{
            Date     = $dt
            Advisory = $advisoryId
            Severity = $severity
            CVSS     = $cvssRaw
            Title    = $item.title
            Link     = $item.link
        }
    }
}

function Get-ConsoleColor {
    <#
    .SYNOPSIS
        Map severity string to a [ConsoleColor] value.
    #>
    param([string]$Severity)

    switch ($Severity.Trim()) {
        'CRIT' { [ConsoleColor]::Red       }
        'HIGH' { [ConsoleColor]::DarkRed   }
        'MEDI' { [ConsoleColor]::Yellow    }
        'LOW'  { [ConsoleColor]::Green     }
        default { [ConsoleColor]::Gray     }
    }
}

function Show-IcsAdvisories {
    <#
    .SYNOPSIS
        Write a color‑coded summary to the console.

    .PARAMETER Items
        Advisory objects to display.
    #>
    param([Parameter(Mandatory, ValueFromPipeline)][object[]]$Items)

    foreach ($row in $Items) {
        $color = Get-ConsoleColor -Severity $row.Severity

        Write-Host ($row.Date.ToString('yyyy-MM-dd')) -ForegroundColor Cyan -NoNewline
        Write-Host ' | ' -NoNewline
        Write-Host $row.Severity -ForegroundColor $color -NoNewline
        Write-Host " | $($row.Advisory) | $($row.Title)"
    }
}

# ── Main execution ────────────────────────────────────────────────────────────
$Cutoff   = (Get-Date).AddDays(-$DaysBack)
$FeedData = Get-IcsAdvisoryFeed -Url $FeedUrl -Cutoff $Cutoff |
            Sort-Object Date -Descending

Show-IcsAdvisories -Items $FeedData
