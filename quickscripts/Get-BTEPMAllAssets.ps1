# There are some prerequisites here - the API key, IP has to be allowed, etc.
## Change These
## Here is how to setup your API Key "LinkHere"
$APISecret = "YOUAPIKEY"
$LoginAsUser = "DOMAIN\USERNAME"
$headers = @{ Authorization="PS-Auth key=$APISecret; runas=$LoginAsUser;"; };
$servername = "servername"


$uri = "https://$servername/BeyondTrust/api/public/v3/Auth/SignAppin"
$uri_AllAssets = "https://$servername/BeyondTrust/api/public/v3/SmartRules/1/Assets"


$signinResult = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -SessionVariable script:session;
#Check your sign in result if you need to

$AllAssets = Invoke-RestMethod -Uri $uri_AllAssets -Method GET -WebSession $script:session -Headers $headers

$AllAssets | Export-Csv -NoTypeInformation C:\temp\EPM_AllAssets.csv
