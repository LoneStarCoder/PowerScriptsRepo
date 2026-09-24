# Giving a Claude Code cloud environment access to a Microsoft 365 tenant

How to set up a Claude Code cloud environment (claude.ai/code) so that Claude can
read a Microsoft 365 / Entra ID tenant through Microsoft Graph, for example to
run `M365/Get-TenantInventory.ps1`.

A cloud session runs in a fresh Linux container that has no Microsoft
credentials. There are two ways to give it access:

| | A. Device code (delegated) | B. App-only via API credentials |
| --- | --- | --- |
| Secret stored in the environment | None | App secret, stored where the session can't read it |
| You must be present | Yes, you sign in with a code each session | No |
| Access is limited by | Your account's roles plus the scopes you consent to | The app's Graph application permissions |
| Works on plan | All | Pro and Max (Team/Enterprise don't have API credentials yet) |
| Best for | One-off scans, exploring | Repeated or scheduled scans (routines) |

**Use a separate environment for each method.** An API credential is attached
to *every* request to `login.microsoftonline.com` from its environment. That
includes device-code sign-ins, which would then carry the wrong client's
credentials.

Never paste a secret into the chat or into **Environment variables**. Anyone
using the environment can read environment variables.

---

## 1. Create the environment (both methods)

1. At claude.ai/code, open the environment menu in the session title bar and choose **Add environment**. You can also edit an existing environment.
2. **Name** it after the method, for example `M365-Delegated` or `M365-AppOnly`.
3. **Network access**: `Full` works. If you use a restricted level, allow at least:
   - `login.microsoftonline.com` and `graph.microsoft.com` for sign-in and Graph
   - `packages.microsoft.com` for PowerShell
   - `www.powershellgallery.com` and its CDN hosts for the Graph module

   Hosts listed on an API credential are reachable at any network level.
4. **Setup script**: installs PowerShell 7 and the Graph authentication module. It takes about a minute. The result is snapshotted, so later sessions skip it.

   ```bash
   #!/bin/bash
   # PowerShell 7 + Microsoft Graph for M365 scripts. Never fail session start.
   set -u
   . /etc/os-release
   if ! command -v pwsh >/dev/null; then
     curl -fsSL "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb" -o /tmp/msprod.deb \
       && dpkg -i /tmp/msprod.deb && apt-get update -qq && apt-get install -y -qq powershell \
       || echo "PowerShell install failed"
   fi
   command -v pwsh >/dev/null && pwsh -NoLogo -NoProfile -Command '
     $ProgressPreference = "SilentlyContinue"
     Set-PSRepository PSGallery -InstallationPolicy Trusted
     Install-Module Microsoft.Graph.Authentication -Scope AllUsers -Force
   ' || echo "Graph module install failed"
   exit 0
   ```

   The script must exit 0, or the session won't start. Keep `exit 0` at the end.
5. **Environment variables** (method B only). These two values are identifiers, not secrets:

   ```
   M365_TENANT_ID=<tenant GUID or yourdomain.com>
   M365_CLIENT_ID=<application (client) ID from step B1>
   ```
6. Save. Changes apply to **new** sessions only.

---

## Method A: device code (no stored secret)

1. Start a new session in the `M365-Delegated` environment.
2. Ask Claude to run the scan with device code sign-in:

   ```
   pwsh ./M365/Get-TenantInventory.ps1 -DeviceCode
   ```
3. Claude relays a message like *"open https://login.microsoft.com/device and enter the code ABC123XYZ"*. Open that page on your own device and enter the code.
4. Sign in with a **Global Reader** account. Global Reader is enough and it's read-only, so avoid Global Admin. Approve the requested scopes: `Directory.Read.All`, `Policy.Read.All`, `AuditLog.Read.All` and `Reports.Read.All`. The first time, an admin must consent for the *Microsoft Graph Command Line Tools* app.
5. The scan continues in the session once you sign in. The token stays in that PowerShell process only and ends with it.

If the sign-in is blocked, check whether a Conditional Access policy blocks the
**device code flow** (*Conditions → Authentication flows*).

---

## Method B: app-only, secret held by the agent proxy

The API credential feature attaches a header to outbound requests *after* they
leave the session, so the secret never enters the container. Entra ID's token
endpoint accepts client credentials as an HTTP Basic header
(`client_secret_basic`). Here is how it fits together:

```
session:  POST login.microsoftonline.com/<tenant>/oauth2/v2.0/token
          grant_type=client_credentials&client_id=...&scope=https://graph.microsoft.com/.default
proxy:    + Authorization: Basic base64(clientId:secret)
Entra:    -> access token (about 60-90 min), which the session uses for graph.microsoft.com
```

Claude sees only the short-lived access token, never the secret.

### B1. Register the app (Entra admin center)

1. Go to **Entra ID → App registrations → New registration**.
   - Name: `Claude-ReadOnly-Scanner`
   - Supported account types: **this organizational directory only**
   - No redirect URI
2. Copy the **Application (client) ID** and **Directory (tenant) ID** from the Overview page.
3. Go to **API permissions → Add a permission → Microsoft Graph → Application permissions** and add:
   - `Directory.Read.All`
   - `Policy.Read.All`
   - `AuditLog.Read.All`
   - `Reports.Read.All`

   Remove the default delegated `User.Read`, which isn't needed. Then choose **Grant admin consent**. Add only `.Read.` permissions. Every session in the environment can mint tokens with whatever you grant.
4. Go to **Certificates & secrets → Client secrets → New client secret**. Use a short expiry, such as 90 days, and copy the **Value** (not the Secret ID) right away.

### B2. Build the Basic credential value (on your own PC)

The header value is `base64(clientId:secret)`. Build it locally so the secret
never appears on screen or in shell history:

```powershell
$ClientId = '<application (client) ID>'
$Secret   = Read-Host 'Client secret' -MaskInput          # PowerShell 7
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${ClientId}:$Secret")) | Set-Clipboard
Remove-Variable Secret
```

Entra secrets contain only `A-Z a-z 0-9 ~ . _ -`, so they need no URL-encoding.

### B3. Add the API credential

1. Edit the `M365-AppOnly` environment. It must already exist, because the create dialog doesn't offer credentials. Under **API credentials**, choose **Add credential**.
2. Fill in the form:
   - **Name**: `Entra token endpoint - <tenant>`
   - **Allowed websites**: `login.microsoftonline.com`
   - **Custom headers**: Name `Authorization`, Prefix `Basic` (change it from `Bearer`), Value is the base64 string from B2
3. Choose **Connect**. The credential saves immediately, and its value can't be viewed again. Clear your clipboard.

Don't add a credential for `graph.microsoft.com`. Graph needs a fresh token
every hour, so a static header there won't work.

### B4. Test

In a **new** session in `M365-AppOnly`, ask Claude to run:

```
pwsh ./M365/Get-TenantInventory.ps1 -ProxyCredential
```

---

## Troubleshooting

| Error | Meaning / fix |
| --- | --- |
| `AADSTS7000216 ... client_secret is required` | The request reached Entra without the credential. Check that the host is exactly `login.microsoftonline.com`, the credential isn't marked **Not sent**, and the session started *after* the credential was added. |
| `AADSTS700016 Application ... was not found` | `M365_CLIENT_ID` or `M365_TENANT_ID` is wrong. |
| `AADSTS7000215 Invalid client secret` | The base64 value is wrong: you used the Secret ID instead of the Value, the client ID differs, or there's a stray space. Delete the credential and add it again, since credentials can't be edited. |
| `AADSTS7000222 ... secret expired` | Create a new secret and replace the credential. |
| `403 Authorization_RequestDenied` | A permission is missing or admin consent wasn't granted. |
| Sign-in activity / MFA section skipped | Needs Entra ID P1/P2. The scan continues without it. |
| Session fails to start | The setup script exited non-zero. Fix it under **Setup script**. |

---

## Housekeeping

- The credential applies to every session in the environment, including scheduled routines, until you delete it. Delete it when you're done.
- Set a calendar reminder for when the secret expires. To rotate it, create a new secret, delete the old credential, add the new one, then delete the old secret in Entra.
- To audit activity, go to **Entra ID → Sign-in logs → Service principal sign-ins** and filter on the app.
- When you no longer need access, delete the app registration.
