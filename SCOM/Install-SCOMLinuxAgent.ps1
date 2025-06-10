<#
.SYNOPSIS
    YOU MUST UPDATE DATA IN THIS SCRIPT. Discovers and installs the SCOM agent on a Linux system via SSH.

.DESCRIPTION
    This script performs the following tasks:
    - Collects the necessary credentials for WSMan and SSH access.
    - Discovers a specified Linux computer using a SCOM Resource Pool.
    - Installs the SCOM agent if discovery is successful.

.PARAMETER WSCredential
    The credential used to authenticate to Linux via WSMan.

.PARAMETER MyPool
    The SCOM Resource Pool used for Linux monitoring.

.PARAMETER Computer
    The FQDN of the Linux server to be discovered and monitored.

.PARAMETER SSHCredential
    SSH credential for the Linux server. It uses a low-privileged account with 'su' elevation.

.EXAMPLE
    Run the script with preconfigured values:
        .\Discover-And-InstallLinuxAgent.ps1

.NOTES
    Update `$computer` before each run to target a new Linux host.
#>


WRITE-HOST "YOU MUST UPDATE DATA IN THIS SCRIPT!!!"
EXIT
### One-Time Setup ##################################################################################################

# Prompt for credentials to use for WSMan-based authentication
$sshuser = "scomlinuxuser"
$WSCredential = Get-Credential -UserName $sshuser

# Define the SCOM Resource Pool used to monitor Linux systems
$MyPool = Get-SCOMResourcePool -Name "Linux Pool"

### Per-Run Configuration ###########################################################################################

# Set the Linux computer FQDN to discover and monitor
$computer = "linux01.domain.com"

# Prompt for SSH credentials for the Linux system, using 'su' for elevation
# First prompt is for opsmgr password, second is for root password
$SSHCredential = Get-SCXSSHCredential -UserName $sshuser -ElevationType "su"

### Agent Discovery and Installation #################################################################################

# Run the discovery against the target Linux host
$DiscResult = Invoke-SCXDiscovery -Name $computer -ResourcePool $MyPool -WSManCredential $WSCredential -SSHCredential $SSHCredential

# Small delay to allow discovery to settle
Start-Sleep -Seconds 2

# If discovery is successful, install the SCOM agent
if ($DiscResult.Succeeded) {
    $installResult = Install-SCXAgent -DiscoveryResult $DiscResult -Verbose
    $installResult | Format-List -Property *
} else {
    $DiscResult | Format-List -Property *
}
