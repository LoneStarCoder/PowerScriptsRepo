param(
    [int]$NumberOfPassphrases = 10,
    [string]$Delimiter = '-',
    [int]$NumberOfWords = 3,
    [bool]$AddRandomNumber = $true,
    [bool]$AddRandomSymbol = $true
)

# Define a function to generate a random passphrase
function Generate-Passphrase {
    param(
        [int]$WordCount,
        [string]$WordDelimiter,
        [bool]$IncludeNumber,
        [bool]$IncludeSymbol
    )

    # Load words from a file assumed to be in the same directory as the script
    $words = Get-Content "C:\google-10000-english-usa-no-swears-medium.txt" -ErrorAction Stop
    $symbols = "!@#$%&*(){}"
    $passphrase = @()

    for ($i = 0; $i -lt $WordCount; $i++) {
         $w = $words | Get-Random
         $passphrase += $w.Substring(0,1).toupper()+$w.Substring(1)
    }

    # Join words with the specified delimiter
    $result = $passphrase -join $WordDelimiter

    # Optionally add a random number
    if ($IncludeNumber) {
        $result += $WordDelimiter + (Get-Random -Minimum 0 -Maximum 9999).ToString()
    }

    # Optionally add a random symbol
    if ($IncludeSymbol) {
        $result += $symbols.ToCharArray() | Get-Random
    }

    return $result
}

# Generate the specified number of passphrases
for ($j = 0; $j -lt $NumberOfPassphrases; $j++) {
    $passphrase = Generate-Passphrase -WordCount $NumberOfWords -WordDelimiter $Delimiter -IncludeNumber $AddRandomNumber -IncludeSymbol $AddRandomSymbol
    Write-Output $passphrase
}
