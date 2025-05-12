<#
.SYNOPSIS
    Displays recent CISA ICS advisories in a color‑coded console view.

.DESCRIPTION
    This script downloads the Cybersecurity & Infrastructure Security Agency (CISA)
    Industrial Control Systems (ICS) advisories RSS feed, filters the entries to the
    last **$DaysBack** days, extracts CVSSv3 scores, maps them to four‑letter severity
    buckets (CRIT, HIGH, MEDI, LOW), and prints each advisory with colorized severity
    for quick triage.

.PARAMETER FeedUrl
    (String) The RSS feed URL to query. Defaults to
    https://www.cisa.gov/cybersecurity-advisories/ics-advisories.xml.

.PARAMETER DaysBack
    (Int) The look‑back window (in days) used to filter advisories based on their
    publication date. Defaults to 14.

.EXAMPLE
    PS> .\Get-ICSAdvisories.ps1
    Shows advisories published in the last 14 days.

.EXAMPLE
    PS> .\Get-ICSAdvisories.ps1 -DaysBack 30
    Shows the last 30 days of advisories.

.NOTES
    Author  : Brody Kilpatrick
    Created : 12 May 2025
    Version : 1.0
#>

[string] $FeedUrl  = 'https://www.cisa.gov/cybersecurity-advisories/ics-advisories.xml'
[int]    $DaysBack = 14

function Get-IcsAdvisoryFeed {
    <#
    .SYNOPSIS
        Download and parse the CISA ICS advisories feed.

    .DESCRIPTION
        Retrieves the RSS feed from the provided URL, converts it to XML,
        and yields one custom object per advisory whose publication date is
        newer than the supplied cutoff.

    .PARAMETER Url
        The RSS feed URL to query.

    .PARAMETER Cutoff
        A [datetime] value; advisories older than this are skipped.

    .OUTPUTS
        [pscustomobject] with the properties:
            Date, Advisory, Severity, CVSS, Title, Link
    #>
    param(
        [Parameter(Mandatory)]
        [string]   $Url,

        [Parameter(Mandatory)]
        [datetime] $Cutoff
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
            default                        { 'LOW ' }
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

function Show-IcsAdvisories {
    <#
    .SYNOPSIS
        Write a color‑coded summary to the console.

    .DESCRIPTION
        Accepts an array of advisory objects (as produced by
        Get-IcsAdvisoryFeed) and writes a one‑line summary for each, with the
        severity column colorized to improve at‑a‑glance scanning.

    .PARAMETER Items
        The advisory objects to display. They must include at least the
        properties: Date, Severity, Advisory, Title.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]] $Items
    )

    foreach ($row in $Items) {
        $sevColor = switch ($row.Severity) {
            'CRIT' { 'Red'     }
            'HIGH' { 'DarkRed' }
            'MEDI' { 'Yellow'  }
            'LOW ' { 'Green'   }
            default { 'Gray'   }
        }

        Write-Host ($row.Date.ToString('yyyy-MM-dd')) -ForegroundColor Cyan -NoNewline
        Write-Host ' | ' -NoNewline
        Write-Host $row.Severity -ForegroundColor $sevColor -NoNewline
        Write-Host " | $($row.Advisory) | $($row.Title)"
    }
}

# ── Main execution ────────────────────────────────────────────────────────────
$Cutoff   = (Get-Date).AddDays(-$DaysBack)
$FeedData = Get-IcsAdvisoryFeed -Url $FeedUrl -Cutoff $Cutoff |
            Sort-Object Date -Descending

Show-IcsAdvisories -Items $FeedData
