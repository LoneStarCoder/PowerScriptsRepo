
# Bleeping Computer
$feed = Invoke-RestMethod 'https://www.bleepingcomputer.com/feed/'
$feed = $feed | Select -first 5

# The Hacker News
$feed = Invoke-RestMethod  'https://feeds.feedburner.com/TheHackersNews'
$feed = $feed | Select -first 5


