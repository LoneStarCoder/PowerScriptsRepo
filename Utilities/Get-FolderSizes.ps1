# Specify the path of the directory you want to analyze
param($directoryPath = "C:\")

# Get all the subdirectories under the specified directory
$directories = Get-ChildItem -Path $directoryPath -Directory

# Initialize an array to hold folder size information
$folderSizes = @()

foreach ($dir in $directories) {
    # Calculate the total size of the files within the directory, including subdirectories
    $sizeBytes = (Get-ChildItem -Path $dir.FullName -File -Recurse | Measure-Object -Property Length -Sum).Sum
    $sizeMB = [math]::Round($sizeBytes / 1MB, 2)
    $sizeGB = [math]::Round($sizeBytes / 1GB, 2)

    # Add the folder and its size to the array
    $folderSizes += New-Object PSObject -Property @{
        Name = $dir.Name
        SizeMB = $sizeMB
        SizeGB = $sizeGB
        SizeBytes = $sizeBytes
    }
}

# Sort the array by size in descending order and output the results
$sortedFolders = $folderSizes | Sort-Object -Property SizeBytes -Descending
$sortedFolders
#foreach ($folder in $sortedFolders) {
#    Write-Output ("{0} has a size of {1} MB ({2} GB)" -f $folder.Name, $folder.SizeMB, $folder.SizeGB)
#}
