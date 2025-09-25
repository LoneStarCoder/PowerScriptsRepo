# Pull only the article content (class="article_section") and print plain text
param(
  [string]$Url = "https://www.bleepingcomputer.com/news/security/new-edr-freeze-tool-uses-windows-wer-to-suspend-security-software/"
)

$raw = (Invoke-WebRequest -UseBasicParsing -Uri $Url).Content
$html = [regex]::Match($raw,'(?is)<article[^>]*>\s*<div class="article_section"[^>]*>([\s\S]*?)</article>').Groups[1].Value
$clean = $html -replace '(?is)<script.*?</script>|<style.*?</style>','' -replace '(?is)<[^>]+>',' ' -replace '\s+',' ' -replace '&nbsp;',' ' -replace '&amp;','&' -replace '&lt;','<' -replace '&gt;','>' -replace '&quot;','"' -replace '&#39;',"'"
$clean.Trim()
