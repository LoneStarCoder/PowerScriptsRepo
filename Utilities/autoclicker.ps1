Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Define mouse event functions using user32.dll
$signature = @'
[DllImport("user32.dll")]
public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, int dwExtraInfo);
'@
Add-Type -MemberDefinition $signature -Name User32 -Namespace Win32

# Mouse event flags
$MOUSEEVENTF_LEFTDOWN = 0x0002
$MOUSEEVENTF_LEFTUP = 0x0004

# Create the GUI form
$form = New-Object System.Windows.Forms.Form
$form.Text = "PowerShell Auto Clicker"
$form.Size = New-Object System.Drawing.Size(300, 200)
$form.StartPosition = "CenterScreen"

# Initialize variables
$script:running = $false
$script:clickInterval = 100  # Initial click interval in milliseconds (0.1 seconds)

# Create label to display click interval
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10, 20)
$label.Size = New-Object System.Drawing.Size(260, 20)
$label.Text = "Click Interval: $script:clickInterval ms"
$form.Controls.Add($label)

# Create Start/Stop button
$startStopButton = New-Object System.Windows.Forms.Button
$startStopButton.Location = New-Object System.Drawing.Point(10, 50)
$startStopButton.Size = New-Object System.Drawing.Size(260, 30)
$startStopButton.Text = "Start"
$startStopButton.Add_Click({
    $script:running = -not $script:running
    if ($script:running) {
        $startStopButton.Text = "Stop"
        # Start clicking in a background job to keep GUI responsive
        $script:job = Start-Job -ScriptBlock {
            param($interval)
            while ($true) {
                if (-not $script:running) { break }
                [Win32.User32]::mouse_event($MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
                [Win32.User32]::mouse_event($MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
                Start-Sleep -Milliseconds $interval
            }
        } -ArgumentList $script:clickInterval
    } else {
        $startStopButton.Text = "Start"
        # Stop the job
        if ($script:job) {
            Stop-Job -Job $script:job
            Remove-Job -Job $script:job
        }
    }
})
$form.Controls.Add($startStopButton)

# Create Increase Speed button
$increaseButton = New-Object System.Windows.Forms.Button
$increaseButton.Location = New-Object System.Drawing.Point(10, 90)
$increaseButton.Size = New-Object System.Drawing.Size(125, 30)
$increaseButton.Text = "Speed Up"
$increaseButton.Add_Click({
    $script:clickInterval = [Math]::Max(10, $script:clickInterval - 10)
    $label.Text = "Click Interval: $script:clickInterval ms"
    # Update interval in running job
    if ($script:running) {
        Stop-Job -Job $script:job
        Remove-Job -Job $script:job
        $script:job = Start-Job -ScriptBlock {
            param($interval)
            while ($true) {
                if (-not $script:running) { break }
                [Win32.User32]::mouse_event($MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
                [Win32.User32]::mouse_event($MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
                Start-Sleep -Milliseconds $interval
            }
        } -ArgumentList $script:clickInterval
    }
})
$form.Controls.Add($increaseButton)

# Create Decrease Speed button
$decreaseButton = New-Object System.Windows.Forms.Button
$decreaseButton.Location = New-Object System.Drawing.Point(145, 90)
$decreaseButton.Size = New-Object System.Drawing.Size(125, 30)
$decreaseButton.Text = "Slow Down"
$decreaseButton.Add_Click({
    $script:clickInterval += 10
    $label.Text = "Click Interval: $script:clickInterval ms"
    # Update interval in running job
    if ($script:running) {
        Stop-Job -Job $script:job
        Remove-Job -Job $script:job
        $script:job = Start-Job -ScriptBlock {
            param($interval)
            while ($true) {
                if (-not $script:running) { break }
                [Win32.User32]::mouse_event($MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
                [Win32.User32]::mouse_event($MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
                Start-Sleep -Milliseconds $interval
            }
        } -ArgumentList $script:clickInterval
    }
})
$form.Controls.Add($decreaseButton)

# Show the form
$form.ShowDialog()
