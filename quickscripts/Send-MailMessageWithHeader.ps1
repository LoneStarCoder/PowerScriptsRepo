$smtpServer = "ImJustASMTPServer"

$msg = New-Object System.Net.Mail.MailMessage
$msg.From = "tst@ImJustASMTPServer"
$msg.To.Add("tst@ImJustASMTPServer")
$msg.Subject = "Test"
$msg.Body = "Test"

# Add your required header
$msg.Headers.Add("X-Super-Test", "thisisjustatest")
#Add Another one if you want
#$msg.Headers.Add("X-Super-Test1", "thisisjustatest")

$smtp = New-Object System.Net.Mail.SmtpClient($smtpServer, 25)
$smtp.EnableSsl = $false
$smtp.Send($msg)
$msg.Dispose()
$smtp.Dispose()
