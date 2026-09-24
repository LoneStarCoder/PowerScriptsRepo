<#
.SYNOPSIS
    Read-only inventory and security snapshot of a Microsoft 365 / Entra ID
    tenant.

.DESCRIPTION
    Collects, through Microsoft Graph v1.0 GET requests only:
        - organization, verified domains and licence (SKU) usage
        - user counts (members, guests, disabled, never signed in, stale)
        - directory role holders, with Global Administrators called out
        - security defaults and Conditional Access policies
        - app registrations with secrets/certificates expired or expiring soon
        - MFA registration summary (needs Entra ID P1/P2; skipped otherwise)

    Each section runs on its own: a section that fails (missing permission,
    missing licence) is recorded and the rest still run. Writes one JSON file
    per section plus Summary.json to the output folder, and prints a summary.

    Three ways to sign in:
      Delegated (default)   Connect-MgGraph interactive sign-in.
      -DeviceCode           Delegated sign-in with a device code. Use this in
                            a headless session (Claude Code cloud, SSH): open
                            https://microsoft.com/devicelogin and enter the code.
      -ProxyCredential      App-only token from the client credentials grant
                            WITHOUT a secret in the session. The secret must be
                            attached to requests for login.microsoftonline.com
                            by an outbound proxy as an
                            "Authorization: Basic base64(clientId:secret)"
                            header (Claude Code cloud "API credentials").
                            Reads -TenantId / -ClientId, or the
                            M365_TENANT_ID / M365_CLIENT_ID variables.

    REQUIREMENTS
    - PowerShell 7+ (Windows PowerShell 5.1 works for the delegated modes)
    - Microsoft.Graph.Authentication module (v2+)
    - Delegated: a Global Reader (or higher) account. Scopes requested:
      Directory.Read.All, Policy.Read.All, AuditLog.Read.All, Reports.Read.All
    - App-only: the same four as application permissions, admin consented
    - signInActivity and MFA registration details need Entra ID P1/P2

.PARAMETER OutputDirectory
    Folder for the export files. Created if missing.

.PARAMETER StaleDays
    A member who has not signed in for this many days counts as stale.
    Default 90.

.PARAMETER ExpiryDays
    App secrets/certificates expiring within this many days are reported.
    Default 30.

.EXAMPLE
    .\Get-TenantInventory.ps1 -DeviceCode

.EXAMPLE
    .\Get-TenantInventory.ps1 -ProxyCredential -OutputDirectory ./scan
#>
[CmdletBinding(DefaultParameterSetName = 'Delegated')]
param(
    [string]$OutputDirectory = './TenantInventory',
    [ValidateRange(1, 3650)]
    [int]$StaleDays = 90,
    [ValidateRange(1, 3650)]
    [int]$ExpiryDays = 30,
    [Parameter(ParameterSetName = 'DeviceCode')]
    [switch]$DeviceCode,
    [Parameter(ParameterSetName = 'ProxyCredential')]
    [switch]$ProxyCredential,
    [Parameter(ParameterSetName = 'ProxyCredential')]
    [string]$TenantId = $env:M365_TENANT_ID,
    [Parameter(ParameterSetName = 'ProxyCredential')]
    [string]$ClientId = $env:M365_CLIENT_ID
)

$ErrorActionPreference = 'Stop'
Import-Module Microsoft.Graph.Authentication

$Scopes  = 'Directory.Read.All', 'Policy.Read.All', 'AuditLog.Read.All', 'Reports.Read.All'
$Graph   = 'https://graph.microsoft.com/v1.0'
$Now     = [datetime]::UtcNow
$Summary = [ordered]@{ CollectedUtc = $Now.ToString('o') }
$Failed  = [ordered]@{}

# Every page of a Graph collection, following @odata.nextLink.
function Get-GraphAll {
    param([string]$Uri)
    while ($Uri) {
        $Page = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
        if ($Page.value) { $Page.value }
        $Uri = $Page.'@odata.nextLink'
    }
}

# Runs one inventory section; a failure is recorded instead of stopping the scan.
function Invoke-Section {
    param([string]$Name, [scriptblock]$Body)
    Write-Host "Collecting $Name..."
    try {
        $Result = & $Body
        $Result | ConvertTo-Json -Depth 20 |
            Set-Content -Path (Join-Path $OutputDirectory "$Name.json") -Encoding utf8
    }
    catch {
        $Failed[$Name] = $_.Exception.Message
        Write-Warning "$Name skipped: $($_.Exception.Message)"
    }
}

New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null

try {
    if ($ProxyCredential) {
        if (-not $TenantId -or -not $ClientId) {
            throw 'Set -TenantId and -ClientId, or M365_TENANT_ID and M365_CLIENT_ID.'
        }
        # No client_secret in the body: the proxy adds the Basic header.
        try {
            $Token = Invoke-RestMethod -Method POST `
                -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
                -Body @{
                    grant_type = 'client_credentials'
                    client_id  = $ClientId
                    scope      = 'https://graph.microsoft.com/.default'
                }
        }
        catch {
            # AADSTS7000216 means the request arrived with no secret at all.
            if ("$_" -match 'AADSTS7000216') {
                throw 'Token request reached Entra ID without a secret: the proxy did not attach the Basic credential for login.microsoftonline.com.'
            }
            throw
        }
        $Secure = ConvertTo-SecureString $Token.access_token -AsPlainText -Force
        Connect-MgGraph -AccessToken $Secure -NoWelcome
    }
    elseif ($DeviceCode) {
        Connect-MgGraph -Scopes $Scopes -UseDeviceCode -ContextScope Process -NoWelcome
    }
    else {
        Connect-MgGraph -Scopes $Scopes -ContextScope Process -NoWelcome
    }
    $Context = Get-MgContext
    Write-Host "Connected to tenant $($Context.TenantId) as $(
        if ($Context.Account) { $Context.Account } else { "app $($Context.ClientId)" })"

    Invoke-Section 'Organization' {
        $Org = Get-GraphAll "$Graph/organization"
        $Summary.Tenant = $Org | Select-Object displayName, id, countryLetterCode, createdDateTime
        $Org
    }

    Invoke-Section 'Domains' {
        $Domains = @(Get-GraphAll "$Graph/domains")
        $Summary.Domains = $Domains | ForEach-Object {
            '{0}{1}{2}' -f $_.id,
                $(if ($_.isDefault) { ' (default)' }),
                $(if (-not $_.isVerified) { ' (UNVERIFIED)' })
        }
        $Domains
    }

    Invoke-Section 'Licenses' {
        $Skus = @(Get-GraphAll "$Graph/subscribedSkus")
        $Summary.Licenses = $Skus | ForEach-Object {
            '{0}: {1} of {2} assigned' -f $_.skuPartNumber, $_.consumedUnits, $_.prepaidUnits.enabled
        }
        $Skus
    }

    Invoke-Section 'Users' {
        $Select = 'id,displayName,userPrincipalName,userType,accountEnabled,createdDateTime,assignedLicenses'
        try {
            $Users = @(Get-GraphAll "$Graph/users?`$top=999&`$select=$Select,signInActivity")
        }
        catch {
            # signInActivity needs Entra ID P1 and AuditLog.Read.All.
            Write-Warning "No sign-in activity ($($_.Exception.Message)); collecting users without it."
            $Users = @(Get-GraphAll "$Graph/users?`$top=999&`$select=$Select")
        }
        $Members = @($Users | Where-Object userType -eq 'Member')
        $Cutoff  = $Now.AddDays(-$StaleDays)
        $Signed  = $Members | Where-Object { $_.signInActivity.lastSignInDateTime }
        $Summary.Users = [ordered]@{
            Total    = $Users.Count
            Members  = $Members.Count
            Guests   = @($Users | Where-Object userType -eq 'Guest').Count
            Disabled = @($Users | Where-Object { -not $_.accountEnabled }).Count
            Licensed = @($Users | Where-Object { $_.assignedLicenses }).Count
        }
        if ($Users | Where-Object { $_.PSObject.Properties['signInActivity'] }) {
            $Summary.Users.NeverSignedIn = @($Members | Where-Object {
                $_.accountEnabled -and -not $_.signInActivity.lastSignInDateTime }).Count
            $Summary.Users."StaleOver${StaleDays}Days" = @($Signed | Where-Object {
                $_.accountEnabled -and [datetime]$_.signInActivity.lastSignInDateTime -lt $Cutoff }).Count
        }
        $Users
    }

    Invoke-Section 'DirectoryRoles' {
        $Roles = foreach ($Role in Get-GraphAll "$Graph/directoryRoles") {
            [pscustomobject]@{
                Role    = $Role.displayName
                Members = @(Get-GraphAll "$Graph/directoryRoles/$($Role.id)/members?`$select=displayName,userPrincipalName" |
                    ForEach-Object { if ($_.userPrincipalName) { $_.userPrincipalName } else { $_.displayName } })
            }
        }
        $Summary.GlobalAdmins = ($Roles | Where-Object Role -eq 'Global Administrator').Members
        $Summary.RoleCounts   = $Roles | Where-Object { $_.Members } |
            ForEach-Object { '{0}: {1}' -f $_.Role, $_.Members.Count }
        $Roles
    }

    Invoke-Section 'SecurityDefaults' {
        $Policy = Invoke-MgGraphRequest -Method GET -OutputType PSObject `
            -Uri "$Graph/policies/identitySecurityDefaultsEnforcementPolicy"
        $Summary.SecurityDefaultsEnabled = $Policy.isEnabled
        $Policy
    }

    Invoke-Section 'ConditionalAccess' {
        $Policies = @(Get-GraphAll "$Graph/identity/conditionalAccess/policies")
        $Summary.ConditionalAccess = $Policies | ForEach-Object { '{0} [{1}]' -f $_.displayName, $_.state }
        $Policies
    }

    Invoke-Section 'AppCredentials' {
        $Soon = $Now.AddDays($ExpiryDays)
        $Rows = foreach ($App in Get-GraphAll "$Graph/applications?`$select=displayName,appId,passwordCredentials,keyCredentials") {
            $Creds = @($App.passwordCredentials | ForEach-Object { @{ Type = 'Secret'; C = $_ } }) +
                     @($App.keyCredentials      | ForEach-Object { @{ Type = 'Certificate'; C = $_ } })
            foreach ($Cred in $Creds) {
                $End = [datetime]$Cred.C.endDateTime
                [pscustomobject]@{
                    App     = $App.displayName
                    AppId   = $App.appId
                    Type    = $Cred.Type
                    Name    = $Cred.C.displayName
                    Expires = $End.ToString('yyyy-MM-dd')
                    Status  = if ($End -lt $Now) { 'Expired' } elseif ($End -lt $Soon) { 'ExpiringSoon' } else { 'OK' }
                }
            }
        }
        $Summary.AppCredentialsNeedingAttention = $Rows | Where-Object Status -ne 'OK' |
            ForEach-Object { '{0} {1} "{2}" {3} {4}' -f $_.App, $_.Type, $_.Name, $_.Status, $_.Expires }
        $Rows
    }

    Invoke-Section 'MfaRegistration' {
        $Details = @(Get-GraphAll "$Graph/reports/authenticationMethods/userRegistrationDetails")
        $Summary.Mfa = [ordered]@{
            Users          = $Details.Count
            MfaRegistered  = @($Details | Where-Object isMfaRegistered).Count
            AdminsNoMfa    = @($Details | Where-Object { $_.isAdmin -and -not $_.isMfaRegistered } |
                                ForEach-Object userPrincipalName)
        }
        $Details
    }

    if ($Failed.Count) { $Summary.SkippedSections = $Failed }
    $Summary | ConvertTo-Json -Depth 10 |
        Set-Content -Path (Join-Path $OutputDirectory 'Summary.json') -Encoding utf8

    Write-Host ''
    Write-Host ($Summary | ConvertTo-Json -Depth 10)
    Write-Host "Files written to $((Resolve-Path $OutputDirectory).Path)"
}
finally {
    if (Get-MgContext) { Disconnect-MgGraph | Out-Null }
}
