<#
.SYNOPSIS
Imports Excel clipboard data into PowerShell as objects by default (headers assumed). It has been tested with basic information and columns. I dont know what it would do with more complex stuff. You could enhance it.

.DESCRIPTION
Get-bExcelArray retrieves the current clipboard contents (expecting tab-delimited data copied from Excel) and converts it into a structured array. By default, it treats the first row as column headers and returns an array of PSCustomObject instances. If you prefer a raw 2D array of strings, use the -Raw switch.

.PARAMETER Raw
Switch to bypass CSV parsing and output a two-dimensional string array (Array-of-Arrays). Without -Raw, data is converted from CSV using headers.

.EXAMPLE
# Copy Excel range to clipboard
$data = Get-bExcelArray
# Returns PSCustomObject[] with properties matching header row

.EXAMPLE
# Copy Excel range to clipboard
$data = Get-bExcelArray -Raw
# Returns an array-of-arrays of strings (no headers)

.NOTES
Version : 1.1
Author  : Brody Kilpatrick
Requires: PowerShell 5.1+
#>
function Get-bExcelArray {
    [CmdletBinding()]
    param(
        [switch]$Raw # Force raw array output
    )

    $txt = Get-Clipboard -Raw
    if ($Raw) {
        # Split into lines, then into columns
        $rows = $txt.TrimEnd() -split "`r?`n"
        return $rows | ForEach-Object { $_ -split "`t" }
    }
    else {
        # Parse as CSV using first row as headers
        return $txt | ConvertFrom-Csv -Delimiter "`t"
    }
}

# Optional alias for convenience
alias gba Get-bExcelArray
