<#
.SYNOPSIS
This script queries Active Directory for certificate templates and their ACLs.

.DESCRIPTION
The script filters out templates published on a given certificate server and outputs to a CSV file.

.NOTES
File Name      : Get-TemplateACLs.ps1
Author         : Brody Kilpatrick
Prerequisite   : PowerShell V2, ActiveDirectory module
Copyright 2023 : Brody Kilpatrick. Use at your own risk.

.EXAMPLE
.\Get-TemplateACLs.ps1 -IssuingCertServer "YourCertServerName"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$IssuingCertServer,

    [string]$OutputPath = "C:\temp\TemplateACLFiltered.csv",

    [string]$LogFile = "C:\temp\TemplateACLs.log"
)

# Function to log messages
function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$timestamp - $Message"
}

# Load the ActiveDirectory module
try {
    Import-Module ActiveDirectory -ErrorAction Stop
} catch {
    Write-Log "Failed to load the ActiveDirectory module. Error: $_"
    exit 1
}

# Fetch configuration naming context
$ConfigContext = ([ADSI]"LDAP://RootDSE").ConfigurationNamingContext

# Get certificate templates
function Get-ADTemplates {
    $ADSI = [ADSI]"LDAP://CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext"
    return $ADSI.Children | Select-Object Name, DisplayName, Path
}

# Get published certificate templates
function Get-PublishedTemplates {
    return Invoke-Command -ComputerName $IssuingCertServer -ScriptBlock { get-catemplate }
}

# Get extended rights lookup
function Get-ExtendedRightsLookup {
    $ExtendedRights = [ADSI]"LDAP://CN=Extended-Rights,$ConfigContext"
    $lookup = @{}
    $ExtendedRights.Children | ForEach-Object {
        $lookup[$_.rightsGuid] = $_.DisplayName
    }
    return $lookup
}

$ADSITemplates = Get-ADTemplates
$PublishedCATemplates = Get-PublishedTemplates
$FilteredTemplates = $ADSITemplates | Where-Object { $_.Name -in $PublishedCATemplates.Name }
$ExtendedRightsLookup = Get-ExtendedRightsLookup

# Process templates and collect ACL details
$TemplateACLArray = @()
$index = 0
$totalCount = $FilteredTemplates.Count
foreach ($ADSITemplate in $FilteredTemplates) {
    $index++
    $progress = ($index / $totalCount) * 100
    Write-Progress -Activity "activity" -PercentComplete $progress -Status "Processing templates" -CurrentOperation "$index of $totalCount"

    $ObjectPathForACL = ($ADSITemplate.Path) -replace "LDAP://", "AD:"
    try {
        $ACLRights = (Get-Acl -Path $ObjectPathForACL).access | Select-Object @{N="TemplateName";E={$ADSITemplate.Name}}, IdentityReference, AccessControlType, ActiveDirectoryRights, ObjectType, @{n='ExtendedProperty'; e={$ExtendedRightsLookup[$_.ObjectType.ToString()]}}
        $TemplateACLArray += $ACLRights
    } catch {
        Write-Log "Error processing template $($ADSITemplate.Name). Error: $_"
    }
}

# Export to CSV
try {
    $TemplateACLArray | Export-Csv -Path $OutputPath -NoTypeInformation
    Write-Log "Data exported to $OutputPath"
} catch {
    Write-Log "Failed to export data to $OutputPath. Error: $_"
    exit 1
}

Write-Host "Data exported to $OutputPath" -ForegroundColor Green
Write-Log "Script completed."
