# Pull only the article content from The Hacker News (id="articlebody") and print plain text
param(
  [string]$Url = "https://thehackernews.com/2025/09/urgent-cisco-asa-zero-day-duo-under.html"
)

$raw = (Invoke-WebRequest -UseBasicParsing -Uri $Url).Content

# Grab the main article div by id and stop before the stopper/notes section
$articleHtml = [regex]::Match(
  $raw,
  '(?is)<div[^>]*id=["'']articlebody["''][^>]*>(.+?)(?=<div[^>]+class=["'']stophere|<div[^>]+class=["'']cf note-b|</article|</section)'
).Groups[1].Value

# Strip scripts/styles, tags, and collapse whitespace
$clean = $articleHtml `
  -replace '(?is)<script.*?</script>|<style.*?</style>','' `
  -replace '(?is)<[^>]+>',' ' `
  -replace '\s+',' '

$clean.Trim()
