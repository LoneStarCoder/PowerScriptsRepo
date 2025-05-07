If your server has **limited or no internet access**, and **CDNs are blocked**, you’ll need to install the `Microsoft.Graph` modules and dependencies **offline**. Microsoft does not bundle everything into a single package, so you’ll have to manually download and transfer all required dependencies. Here's a deep dive into your **offline installation options**.

---

## 🧰 Option 1: Manual Download and Import (Fully Offline Method)

### 🔹 **1. On an Internet-Connected Machine:**

Use a clean machine with PowerShell 7 or 5.1 and install the module(s) you want:

```powershell
Save-Module -Name Microsoft.Graph.Authentication -Path "C:\GraphModules" -Force
```

> This will download the main module and its **direct dependencies** to `C:\GraphModules`.

If you're installing the full Graph SDK:

```powershell
Save-Module -Name Microsoft.Graph -Path "C:\GraphModules" -Force
```

### 🔹 **2. Copy the Folder to the Offline Server**

Copy the entire `Microsoft.Graph.*` module folders (including all dependencies like `Microsoft.Graph.Authentication`, `Microsoft.Graph.Core`, `Microsoft.Graph.Users`, etc.) to a folder on your offline server, for example:

```plaintext
D:\OfflineModules\
├── Microsoft.Graph.Authentication
├── Microsoft.Graph.Users
├── Microsoft.Graph.Core
...
```

### 🔹 **3. Import Modules on the Offline Server**

```powershell
$ModulePath = "D:\OfflineModules\Microsoft.Graph.Authentication"
Import-Module "$ModulePath\Microsoft.Graph.Authentication.psd1"
```

Or, to make them available persistently:

```powershell
$env:PSModulePath += ";D:\OfflineModules"
```

You can also copy them into your user module path:

```powershell
Copy-Item -Recurse -Path "D:\OfflineModules\*" -Destination "$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
```

---

## 🧰 Option 2: Create an Internal PowerShell Gallery (Advanced)

If you're managing multiple offline or semi-isolated servers, it's worth setting up an **internal PowerShell repository**:

1. **Host a NuGet-based PSGallery clone**:

   * Use [NuGet.Server](https://learn.microsoft.com/en-us/nuget/hosting-packages/nuget-server) or \[Azure Artifacts] or any IIS/SMB/Nexus3 repository.
   * Populate with Graph modules using `Save-Module`.

2. **Point servers to your internal repo**:

   ```powershell
   Register-PSRepository -Name "InternalRepo" -SourceLocation "http://your-internal-server/nuget" -InstallationPolicy Trusted
   ```

3. Install from there:

   ```powershell
   Install-Module -Name Microsoft.Graph.Authentication -Repository "InternalRepo"
   ```

This method allows for centralized patching and easier updates long-term.

---

## 🧩 Option 3: Use Package Reference or Zip Extraction (Last Resort)

If strict policies block `.psd1` execution, you can:

* Extract `.nupkg` files directly from PowerShell Gallery (on a machine with access).
* Rename `.nupkg` to `.zip`, extract it manually.
* Copy the contents into your module path.

---

## 🧪 Pro Tip: Get All Dependencies

If you're not sure what dependencies to grab, this command helps:

```powershell
Save-Module Microsoft.Graph -Path C:\GraphModules -Force -RequiredVersion 2.14.0 -Verbose
```

This ensures you get every nested submodule under `Microsoft.Graph.*`.
