function Get-HelloWorld {
<#
.SYNOPSIS
Outputs a greeting to the console.

.DESCRIPTION
The Get-HelloWorld function outputs a simple greeting message, "Hello, World!".

.EXAMPLE
Get-HelloWorld
#>
    Write-Output "Hello, World!"
}

Function Get-FolderSizes {
    <#
.SYNOPSIS
Retrieves sizes of subdirectories within a given directory.

.DESCRIPTION
The Get-FolderSizes function calculates the size of each subdirectory under a specified path, returning the sizes in MB, GB, and bytes. It lists directories sorted by their size in descending order.

.PARAMETER directoryPath
The path of the directory to analyze. Defaults to "C:\Users" if not specified.

.EXAMPLE
Get-FolderSizes -directoryPath "C:\Users"
Calculates and displays the sizes of subdirectories under "C:\Users".
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$directoryPath = "C:\Users"
    )
    
    # Try to get all subdirectories; catch and handle errors if the path is inaccessible.
    try {
        $directories = Get-ChildItem -Path $directoryPath -Directory -ErrorAction Stop
    }
    catch {
        Write-Error "Unable to access directory at path '$directoryPath'. Error: $_"
        return
    }

    # Initialize an array to hold folder size information.
    $folderSizes = @()

    foreach ($dir in $directories) {
        try {
            # Calculate the total size of the files within the directory, including subdirectories.
            $sizeBytes = (Get-ChildItem -Path $dir.FullName -File -Recurse -ErrorAction Stop | Measure-Object -Property Length -Sum).Sum
            $sizeMB = [math]::Round($sizeBytes / 1MB, 2)
            $sizeGB = [math]::Round($sizeBytes / 1GB, 2)

            # Add the folder and its size to the array.
            $folderSizes += New-Object PSObject -Property @{
                Name = $dir.Name
                SizeMB = $sizeMB
                SizeGB = $sizeGB
                SizeBytes = $sizeBytes
            }
        }
        catch {
            Write-Warning "Unable to calculate size for directory '$($dir.FullName)'. Error: $_"
        }
    }
    
    # Sort folders by size in descending order and return.
    $sortedFolders = $folderSizes | Sort-Object -Property SizeBytes -Descending
    return $sortedFolders
}

function Start-KeepAlive {
<#
.SYNOPSIS
Keeps the session active by simulating a key press at a specified interval.

.DESCRIPTION
The Start-KeepAlive function prevents the system from going into a sleep state or activating the screensaver by simulating the pressing of the F15 key on the keyboard. It does this repeatedly for a specified number of times and intervals.

.PARAMETER Times
The number of times to simulate the key press. Defaults to 100 if not specified.

.PARAMETER IntervalSeconds
The time interval in seconds between each simulated key press. Defaults to 100 seconds if not specified.

.EXAMPLE
Start-KeepAlive -Times 50 -IntervalSeconds 120

This command simulates an F15 key press 50 times with a 120-second interval between each press.

.NOTES
This function uses the COM object wscript.shell to send the keystrokes. Ensure that the PowerShell window remains in focus for SendKeys to work correctly. The total runtime is displayed and updated after each interval.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [int]$Times = 100,

        [Parameter(Mandatory=$false)]
        [int]$Intervalseconds = 100
    )

    $wshell = New-Object -ComObject wscript.shell;
    [int]$TotalTime =  $Times * $Intervalseconds
    Write-Host (Get-Date) -ForegroundColor Green
    Write-Host "Keeping Alive for $TotalTime Seconds" -ForegroundColor Yellow
    for ($i=1; $i -le $Times; $i++) {
        $wshell.SendKeys("{F15}")
        Start-Sleep -Seconds $Intervalseconds
        $TotalTime=$TotalTime-$Intervalseconds
        Write-Output "Time Left $TotalTime"
    }
}


Function Get-Art {
$art = @"
mm                    
*@@@@*                                         m@***@m@  @@                       @@          mm@***@m@                *@@@                    
  @@                                          m@@    *@  @@                       @@        m@@*     *@                  @@                    
  @@        m@@*@@m *@@@@@@@@m    mm@*@@      *@@@m    @@@@@@  m@*@@m  *@@@m@@@ @@@@@@      @@*       *  m@@*@@m    m@**@@@    mm@*@@ *@@@m@@@ 
  @@       @@*   *@@  @@    @@   m@*   @@       *@@@@@m  @@   @@   @@    @@* **   @@        @@          @@*   *@@ m@@    @@   m@*   @@  @@* ** 
  @!     m @@     @@  @!    @@   !@******           *@@  @@    m@@@!@    @!       @@        @!m         @@     @@ @!@    @!   !@******  @!     
  @!    :@ @@     !@  @!    !@   !@m    m     @@     @@  @!   @!   !@    @!       @!        *!@m     m* @@     !@ *!@    @!   !@m    m  @!     
  !!     ! !@     !!  !!    !!   !!******     !     *@!  !!    !!!!:!    !!       !!        !!!         !@     !! !!!    !!   !!******  !!     
  !:    !! !!!   !!!  !!    !!   :!!          !!     !!  !!   !!   :!    !:       !!        :!!:     !* !!!   !!! *:!    !:   :!!       !:     
: :: !: :   : : : : : :::  :!: :  : : ::      :!: : :!   ::: ::!: : !: : :::      ::: :       : : : :!   : : : :   : : : ! :   : : :: : :::    
"@
return $art
}
Get-Art

# End of module functions

###########################