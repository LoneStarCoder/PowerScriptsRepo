# PowerScriptsRepo

A collection of PowerShell scripts for Windows system administration, security auditing, and day-to-day utility tasks. Scripts are grouped by the product or area they target: Active Directory, PKI, SCOM, SCCM, Exchange, Windows Firewall, Group Policy, Microsoft 365 and general utilities.

## Disclaimer

These scripts are provided as-is, without warranty of any kind. Users are free to use and modify them, but do so at their own risk. The author assumes no responsibility for any issues that may arise from their use. **Read a script before running it**, especially anything that deletes files, resolves alerts, or changes system settings, and test in a non-production environment first.

## Getting started

```powershell
git clone https://github.com/LoneStarCoder/PowerScriptsRepo.git
cd PowerScriptsRepo

# Allow locally cloned scripts to run for this session only
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Scripts with comment-based help can describe themselves
Get-Help .\Utilities\Scan-Network.ps1 -Full
```

General notes:

- Most scripts target **Windows PowerShell 5.1**; many also run on PowerShell 7.
- Scripts that talk to a product (SCOM, SCCM, Exchange, AD, Graph) need that product's PowerShell module and suitable permissions.
- Scripts in `quickscripts/` and several others contain **placeholder values** (server names, site codes, API keys, email addresses, `C:\temp` output paths). Edit them for your environment before running.

## Repository layout

### AD – Active Directory

| Script | Description |
| --- | --- |
| `Track-NTLM-Events.ps1` | Exports events from the `Microsoft-Windows-NTLM/Operational` log (IDs 8001–8004, 4014, 4024) to CSV, including workstation, user and secure-channel names. Useful for finding NTLM usage before restricting it. Parameters: `-Days` (default 7), `-OutputCsv`. |

### BrodyModule – personal module

`BrodyModule.psm1` / `BrodyModule.psd1` bundle commonly used functions (`Get-FolderSizes`, `Start-KeepAlive`, `Get-HelloWorld`, `Get-Art`) into one importable module:

```powershell
Import-Module .\BrodyModule\BrodyModule.psd1
Get-FolderSizes -directoryPath 'C:\Users'
```

### ChatGPT

| Script | Description |
| --- | --- |
| `SetupPowerShellAI.ps1` | Notes for installing and trying the community `PowerShellAI` module. Set your own OpenAI API key; never commit it. |
| `ChatGPTChatLoop.ps1` | Placeholder (empty). |

### GPO – Group Policy

| Script | Description |
| --- | --- |
| `Get All GPOs with a Specific Setting.ps1` | Searches the XML report of every GPO in the domain for a string and lists the matching settings (Administrative Templates, registry policy, registry preferences, scripts). Set `$search` at the top of the script. Requires the `GroupPolicy` module. |

### M365 – Microsoft 365

| Script | Description |
| --- | --- |
| `Get-CopilotPackageRegistry.ps1` | Exports the Microsoft 365 Copilot package registry (agents, Teams apps, Office add-ins) through the Microsoft Graph Package Management API. Retries the intermittent `424 Failed Dependency` responses and writes JSON, plus an optional flattened CSV. Requires `Microsoft.Graph.Authentication`, the `CopilotPackages.Read.All` permission and Microsoft Agent 365 licensing. |

```powershell
.\M365\Get-CopilotPackageRegistry.ps1 -AgentsOnly -ExportCsv
```

### PKI – Certificate Services

| Script | Description |
| --- | --- |
| `Get-TemplateACLs_v2.ps1` | Lists the certificate templates published on a given issuing CA and exports each template's ACL, including extended rights such as Enroll/Autoenroll, to CSV. Useful for ADCS permission reviews. Requires the `ActiveDirectory` module and remoting to the CA. |

```powershell
.\PKI\Get-TemplateACLs_v2.ps1 -IssuingCertServer 'YourCertServerName' -OutputPath 'C:\temp\TemplateACLs.csv'
```

### RSS_Summarizer

| Script | Description |
| --- | --- |
| `RSS_GetFeeds.ps1` | Pulls the latest items from the BleepingComputer and The Hacker News RSS feeds (work in progress). |
| `Content_BleepingComputer.ps1` | Extracts the plain article text from a BleepingComputer article (`-Url`). |
| `Content_TheHackerNews.ps1` | Extracts the plain article text from a Hacker News article (`-Url`). |

### SCOM – System Center Operations Manager

All SCOM scripts require the `OperationsManager` module and a management server name set in the script.

| Script | Description |
| --- | --- |
| `Get-SCOMAgents.ps1` | Exports all agents from a production and a development management group to CSV. |
| `Install-SCOMLinuxAgent.ps1` | Discovers a Linux host through a resource pool and installs the SCOM agent over SSH. Exits immediately until you edit the values in the script. |
| `Process-activeSCOMAlerts.ps1` | Interactive loop that shows new critical/warning alerts every minute and lets you pick a resolution state for each. Monitor-based alerts set to 255 have their monitor reset. |
| `ResetActiveAlerts.ps1` | Resolves **every** new alert: resets the monitor for monitor-based alerts and closes rule-based alerts. |
| `Resolve SCOM Alerts from a Llist.ps1` | Defines `Resolve-SCOMAlertlist`, which resolves alerts whose names appear in a text file. Use `-Resolve $false` to preview without changing anything. |

### Security

| Script | Description |
| --- | --- |
| `DisableNBT.ps1` | **Audit only.** Returns the number of IP-enabled network adapters that still have NetBIOS over TCP/IP enabled (`0` means compliant). Suitable as a compliance/detection script; it does not change any settings. |
| `Get-ICSAdvisories.ps1` | Downloads the CISA ICS advisories feed and prints recent advisories colour-coded by CVSS severity (CRIT/HIGH/MEDI/LOW/UNKN). Parameters: `-DaysBack` (default 30), `-FeedUrl`. |

### Utilities

| Script | Description |
| --- | --- |
| `Scan-Network.ps1` | Multi-threaded TCP port scanner for IPs, CIDR ranges or 3-octet prefixes. Supports port presets (`Web`, `Windows`, `Admin`, `Common`), optional ping and reverse-DNS, and CSV or pipeline output. See `Get-Help -Full` for all options. |
| `fastportscanner.ps1` | Minimal runspace-based port scanner for a single host (settings at the top of the script). For accurate results and more options use `Scan-Network.ps1`. |
| `Get-FolderSizes.ps1` | Defines `Get-FolderSizes`, which reports the size of each subfolder of a path in bytes, MB and GB. |
| `Get-bExcelArray.ps1` | Defines `Get-bExcelArray` (alias `gba`), which turns cells copied from Excel into PowerShell objects using the header row, or raw arrays with `-Raw`. |
| `Remove-OldFiles.ps1` | Defines `Remove-OldFiles`, which deletes files with a given extension older than N days in one folder and emails the list of deleted files. Configure the SMTP parameters first. |
| `keepalive.ps1` / `Start-Keepalive.ps1` | Prevent sleep or screen lock by pressing F15 at an interval. `Start-Keepalive.ps1` defines `Start-KeepAlive -Times -IntervalSeconds`. |
| `autoclicker.ps1` | Small Windows Forms auto-clicker with start/stop and speed controls. |
| `clear-clipboard.ps1` | Watches the clipboard and clears anything copied to it after 3 seconds. Runs until stopped. |
| `send-syslog.ps1` | Sends a single test syslog message over UDP 514. Set the server and message in the script. |
| `wait-unilenterortimeout.ps1` | Pauses until Enter is pressed or a timeout (default 30 seconds) expires. |

### WindowsFirewall

| Script | Description |
| --- | --- |
| `Query-FWRulesFromGPO.ps1` | Exports firewall rules applied by Group Policy (RSOP) to CSV and prints each rule's filters (security, port, service, application, address). |
| `QueryWindowsFirewallLogs.ps1` | Parses `pfirewall.log` into objects for dropped traffic, ignoring common multicast/broadcast noise. Parameters: `-Path`, `-Direction` (`RECEIVE` or `SEND`). Example queries are included in the notes at the bottom. |

### quickscripts

Short, single-purpose scripts. Edit the placeholder values before running.

| Script | Description |
| --- | --- |
| `Get-BTEPMAllAssets.ps1` | Signs in to the BeyondTrust EPM REST API and exports all assets to CSV. Needs an API key and an allowed source IP. |
| `Get-SCCMActiveClients.ps1` | Exports active Configuration Manager clients with their key properties to CSV. Set `$sitecode`. |
| `Get-SCOMAgents.ps1` | Quick export of SCOM agents from two management groups. |
| `QueryExchangeReceiveConnectorLogs.ps1` | Parses the last 3 days of Exchange front-end SMTP receive protocol logs and lists unique EHLO values. |
| `QueryIISSMTPLogs_forClients.ps1` | Parses the last 7 days of IIS SMTP logs and lists unique client IP/username pairs that sent EHLO. |
| `Remove-OldLogFiles.ps1` | ⚠️ Deletes **every** `*.log` file older than 120 days anywhere on `C:\`, without confirmation. Narrow the path before use. |
| `Send-MailMessageWithHeader.ps1` | Sends a test email with a custom `X-` header through an SMTP relay. |

### Root

| File | Description |
| --- | --- |
| `Generate-Passphrase.ps1` | Generates readable passphrases (for example `Garden-Silver-Planet-4821!`) from the bundled word list. Run it from the repository root so it can find `google-10000-english-usa-no-swears-medium.txt`. Parameters: `-NumberOfPassphrases`, `-NumberOfWords`, `-Delimiter`, `-AddRandomNumber`, `-AddRandomSymbol`. |
| `google-10000-english-usa-no-swears-medium.txt` | Word list used by `Generate-Passphrase.ps1`. |
| `LoneStarCoderAsciiArt.ps1` | ASCII-art banner. |

### helpfulprocedures

| File | Description |
| --- | --- |
| `installing_psmodules_offline.md` | How to install `Microsoft.Graph` and other PowerShell Gallery modules on servers with no internet access. |
