<#
.SYNOPSIS
   Deletes files in a specified folder that are older than a given number of days and sends an email notification if files are deleted.

.DESCRIPTION
   The Remove-OldFiles function scans a designated folder for files with a specified extension that are older than the provided age (in days). If matching files are found, they are deleted and an email is sent with a list of the deleted files. The function includes configurable SMTP parameters for sending the notification.

.PARAMETER Path
   The full path to the folder where the function will search for files.

.PARAMETER Extension
   The file extension to target (for example, "log"). You can supply the extension with or without a leading dot.

.PARAMETER Age
   The age threshold in days. Files older than this number will be deleted.

.PARAMETER SMTPServer
   The address of the SMTP server used to send the email. Default: "smtp.domain.com".

.PARAMETER SMTPPort
   The port number for the SMTP server. Default: 25.

.PARAMETER From
   The sender's email address for the notification email.

.PARAMETER To
   The recipient's email address for the notification email.

.PARAMETER Subject
   The subject line for the notification email. Default: "Old Files Deleted Notification".

.EXAMPLE
   Remove-OldFiles -Path "E:\test" -Extension "log" -Age 30
   This example deletes all .log files in the E:\test folder that are older than 30 days and sends an email notification listing the deleted files.

.NOTES
   Ensure that the SMTP settings (SMTPServer, SMTPPort, From, and To) are correctly configured.
   Author: Brody Kilpatrick
   Version: 1.0
#>

function Remove-OldFiles {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$Extension,
        
        [Parameter(Mandatory=$true)]
        [int]$Age,  # Age in days
        
        [string]$SMTPServer = "smtp.domain.com",
        [int]$SMTPPort = 25,
        [string]$From = "afakeusername@domain.com",
        [string]$To = "afakeusername@domain.com",
        [string]$Subject = "Old Files Deleted Notification"
    )

    # Ensure the extension doesn't have a leading dot
    if ($Extension.StartsWith(".")) {
        $Extension = $Extension.TrimStart(".")
    }

    # Calculate cutoff date based on age (in days)
    $cutoffDate = (Get-Date).AddDays(-$Age)

    # Find files with the given extension older than the cutoff date
    $filesToDelete = Get-ChildItem -Path $Path -Filter "*.$Extension" -File | Where-Object { $_.LastWriteTime -lt $cutoffDate }

    if ($filesToDelete) {
        # Delete the files
        $filesToDelete | Remove-Item -Force

        # Build email body with list of deleted files
        $fileList = $filesToDelete | ForEach-Object { $_.FullName } | Out-String
        $body = "The following files older than $Age days have been deleted:`n$fileList"

        # Send the email notification
        Send-MailMessage -From $From -To $To -Subject $Subject -Body $body -SmtpServer $SMTPServer -Port $SMTPPort
    }
    else {write-host "Nothing to delete"}
}


#test
#Remove-OldFiles -Path "E:\test" -Extension "log" -Age 30
