Write-Host "=== Find text in all GPOs (structured XML parse) ===" -ForegroundColor Cyan

# ---- set your search string (literal, case-insensitive) ----
$search = "guest"
if ([string]::IsNullOrWhiteSpace($search)) { Write-Error "Search string is required."; exit 1 }

# -------------------- helpers (PS5.1-safe) --------------------
function Get-AttrValue {
    param([System.Xml.XmlNode]$Node, [string]$AttrName)
    if ($null -eq $Node) { return $null }
    if ($Node -is [System.Xml.XmlElement]) {
        $v = $Node.GetAttribute($AttrName)
        if ([string]::IsNullOrEmpty($v)) { return $null } else { return $v }
    }
    if ($Node.Attributes -and $Node.Attributes[$AttrName]) { return $Node.Attributes[$AttrName].Value }
    return $null
}
function Get-NodeText {
    param([System.Xml.XmlNode]$Node, [string]$XPath)
    if ($null -eq $Node) { return $null }
    $n = $Node.SelectSingleNode($XPath)
    if ($n) { return $n.InnerText } else { return $null }
}
function Contains-CI { param([string]$Haystack,[string]$Needle)
    if ([string]::IsNullOrEmpty($Haystack) -or [string]::IsNullOrEmpty($Needle)) { return $false }
    return $Haystack.ToLower().Contains($Needle.ToLower())
}
function New-Row { param([string]$GPOName,[string]$Section,[string]$Setting,[string]$Values)
    [pscustomobject]@{ GPOName = $GPOName; Section = $Section; Setting = $Setting; Values = $Values }
}
# Safe adder: adds items one-by-one (no AddRange typing issues)
function Add-Rows {
    param([System.Collections.Generic.List[object]]$Target, [object]$Items)
    if ($null -eq $Items) { return }
    $enumerable = $Items
    # If it's not IEnumerable OR it's a string, treat as single item
    if (-not ($Items -is [System.Collections.IEnumerable]) -or ($Items -is [string])) { $enumerable = @($Items) }
    foreach ($it in $enumerable) {
        if ($null -ne $it) { [void]$Target.Add($it) }
    }
}

# ---- Extractors ----

# 1) Administrative Templates (Policy nodes)
function Extract-AdminTemplate {
    param([xml]$Xml,[string]$Search,[string]$GPOName)
    $rows = New-Object System.Collections.Generic.List[object]
    $policies = (Select-Xml -Xml $Xml -XPath "//*[local-name()='Policy']" -EA SilentlyContinue).Node
    foreach ($p in $policies) {
        if (-not (Contains-CI $p.OuterXml $Search)) { continue }
        $name = Get-AttrValue $p 'Name'
        if (-not $name) { $name = Get-NodeText $p ".//*[local-name()='Name' and not(*)]" }
        if (-not $name) { $name = "(Policy)" }

        $vals = @()
        $state = Get-NodeText $p ".//*[local-name()='State']"
        if ($state) { $vals += "State=$state" }

        $elements = $p.SelectNodes(".//*[local-name()='Element']")
        if ($elements) {
            foreach ($el in $elements) {
                $elName = (Get-AttrValue $el 'Name'); if (-not $elName) { $elName = Get-AttrValue $el 'name' }
                $elVal = $null
                $v1 = Get-NodeText $el ".//*[local-name()='Value']"
                $v2 = Get-NodeText $el ".//*[local-name()='Data']"
                if ($v1) { $elVal = $v1 } elseif ($v2) { $elVal = $v2 }
                if ($elName -or $elVal) {
                    if ($elName -and $elVal -ne $null) { $vals += "$elName=$elVal" }
                    elseif ($elName)                   { $vals += "$elName" }
                    elseif ($elVal -ne $null)          { $vals += "$elVal" }
                }
            }
        }

        $tripNodes = $p.SelectNodes(".//*[local-name()='Key' or local-name()='ValueName' or local-name()='Value']/..")
        if ($tripNodes) {
            foreach ($tn in $tripNodes) {
                $key = Get-NodeText $tn ".//*[local-name()='Key']"
                $vn  = Get-NodeText $tn ".//*[local-name()='ValueName']"
                $vv  = Get-NodeText $tn ".//*[local-name()='Value']"
                $kv  = @()
                if ($key) { $kv += "Key=$key" }
                if ($vn)  { $kv += "ValueName=$vn" }
                if ($vv -ne $null) { $kv += "Value=$vv" }
                if ($kv.Count -gt 0) { $vals += ($kv -join "; ") }
            }
        }

        Add-Rows -Target $rows -Items (New-Row -GPOName $GPOName -Section 'AdminTemplate' -Setting $name -Values ($vals -join " | "))
    }
    $rows
}

# 2) Registry Policy (triplets anywhere in ExtensionData)
function Extract-RegPolicy {
    param([xml]$Xml,[string]$Search,[string]$GPOName)
    $rows = New-Object System.Collections.Generic.List[object]
    $nodes = (Select-Xml -Xml $Xml -XPath "//*[local-name()='ExtensionData']/*[local-name()='Extension']//*[local-name()='Key' or local-name()='ValueName' or local-name()='Value']/.." -EA SilentlyContinue).Node | Select-Object -Unique
    foreach ($n in $nodes) {
        if (-not (Contains-CI $n.OuterXml $Search)) { continue }

        $nameNode = $n.SelectSingleNode("(ancestor-or-self::*[@Name or @name])[1]")
        $name = $null
        if ($nameNode) { $name = Get-AttrValue $nameNode 'Name'; if (-not $name) { $name = Get-AttrValue $nameNode 'name' } }
        if (-not $name) { $name = Get-NodeText $n ".//*[local-name()='ValueName']" }
        if (-not $name) { $name = "(Registry Policy)" }

        $key = Get-NodeText $n ".//*[local-name()='Key']"
        $vn  = Get-NodeText $n ".//*[local-name()='ValueName']"
        $vv  = Get-NodeText $n ".//*[local-name()='Value']"

        $vals = @()
        if ($key) { $vals += "Key=$key" }
        if ($vn)  { $vals += "ValueName=$vn" }
        if ($vv -ne $null) { $vals += "Value=$vv" }

        if ($vals.Count -gt 0) {
            Add-Rows -Target $rows -Items (New-Row -GPOName $GPOName -Section 'RegPolicy' -Setting $name -Values ($vals -join "; "))
        }
    }
    $rows
}

# 3) Preferences -> Registry
function Extract-PrefRegistry {
    param([xml]$Xml,[string]$Search,[string]$GPOName)
    $rows = New-Object System.Collections.Generic.List[object]
    $regs = (Select-Xml -Xml $Xml -XPath "//*[local-name()='Registry']" -EA SilentlyContinue).Node
    foreach ($r in $regs) {
        if (-not (Contains-CI $r.OuterXml $Search)) { continue }
        $name  = Get-AttrValue $r 'name'
        $props = $r.SelectSingleNode(".//*[local-name()='Properties']")
        if (-not $name) { $name = Get-AttrValue $props 'valuename' }
        if (-not $name) { $name = "(Pref Registry)" }

        $vals = @()
        foreach ($attr in 'action','hive','key','valuename','value','type','default') {
            $v = Get-AttrValue $props $attr
            if ($v) { $vals += "$attr=$v" }
        }
        Add-Rows -Target $rows -Items (New-Row -GPOName $GPOName -Section 'PrefRegistry' -Setting $name -Values ($vals -join "; "))
    }
    $rows
}

# 4) Scripts
function Extract-Scripts {
    param([xml]$Xml,[string]$Search,[string]$GPOName)
    $rows = New-Object System.Collections.Generic.List[object]
    $scripts = (Select-Xml -Xml $Xml -XPath "//*[local-name()='Script']" -EA SilentlyContinue).Node
    foreach ($s in $scripts) {
        if (-not (Contains-CI $s.OuterXml $Search)) { continue }
        $name = Get-AttrValue $s 'Name'; if (-not $name) { $name = "Script" }
        $cmd  = Get-NodeText $s ".//*[local-name()='Command']"
        $par  = Get-NodeText $s ".//*[local-name()='Parameters']"
        $vals = @()
        if ($cmd) { $vals += "Command=$cmd" }
        if ($par) { $vals += "Params=$par" }
        Add-Rows -Target $rows -Items (New-Row -GPOName $GPOName -Section 'Scripts' -Setting $name -Values ($vals -join " | "))
    }
    $rows
}

# 5) Generic fallback (only if nothing else matched in that GPO)
function Extract-GenericFallback {
    param([xml]$Xml,[string]$Search,[string]$GPOName)
    $rows = New-Object System.Collections.Generic.List[object]
    $lc = $Search.ToLower()
    $hits = (Select-Xml -Xml $Xml -XPath "//*[contains(translate(.,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'),'$lc')]" -EA SilentlyContinue).Node
    foreach ($g in $hits) {
        $named = $g.SelectSingleNode("(ancestor-or-self::*[@Name or @name])[1]")
        $name = $null
        if ($named) { $name = Get-AttrValue $named 'Name'; if (-not $name) { $name = Get-AttrValue $named 'name' } }
        if (-not $name) { $name = "(Unnamed)" }

        $vals = @()
        foreach ($attr in 'State','state','value','Value','ValueName','Key','path','Path') {
            $v = Get-AttrValue $named $attr
            if ($v) { $vals += "$attr=$v" }
        }
        foreach ($elem in 'State','Value','Data','Command','Parameters','Path') {
            $v = Get-NodeText $named ".//*[local-name()='$elem']"
            if ($v) { $vals += "$elem=$v" }
        }
        if ($vals.Count -gt 0) {
            Add-Rows -Target $rows -Items (New-Row -GPOName $GPOName -Section 'Generic' -Setting $name -Values ($vals -join " | "))
        }
    }
    $rows
}

# -------------------- main --------------------
try { $gpos = Get-GPO -All -ErrorAction Stop }
catch { Write-Error "Unable to enumerate GPOs. $($_.Exception.Message)"; exit 1 }

$regex   = [regex]::Escape($search)
$results = New-Object System.Collections.Generic.List[object]
$total   = $gpos.Count
$index   = 0

foreach ($gpo in $gpos) {
    $index++
    Write-Progress -Activity "Scanning GPOs" -Status "$index / $total : $($gpo.DisplayName)" -PercentComplete (($index / [math]::Max($total,1)) * 100)
    try {
        $xmlReport = Get-GPOReport -Guid $gpo.Id -ReportType Xml -ErrorAction Stop
        if ($null -eq $xmlReport -or $xmlReport -notmatch $regex) { continue }

        [xml]$doc = $xmlReport

        $gpoRows = New-Object System.Collections.Generic.List[object]
        Add-Rows -Target $gpoRows -Items (Extract-AdminTemplate -Xml $doc -Search $search -GPOName $gpo.DisplayName)
        Add-Rows -Target $gpoRows -Items (Extract-RegPolicy     -Xml $doc -Search $search -GPOName $gpo.DisplayName)
        Add-Rows -Target $gpoRows -Items (Extract-PrefRegistry  -Xml $doc -Search $search -GPOName $gpo.DisplayName)
        Add-Rows -Target $gpoRows -Items (Extract-Scripts       -Xml $doc -Search $search -GPOName $gpo.DisplayName)

        if ($gpoRows.Count -eq 0) {
            Add-Rows -Target $gpoRows -Items (Extract-GenericFallback -Xml $doc -Search $search -GPOName $gpo.DisplayName)
        }

        # merge
        foreach ($row in $gpoRows) { [void]$results.Add($row) }
    } catch {
        Write-Warning "Failed to scan GPO '$($gpo.DisplayName)': $($_.Exception.Message)"
    }
}

if ($results.Count -eq 0) {
    Write-Host "No matches found for '$search'." -ForegroundColor Yellow
} else {
    $results |
        Sort-Object GPOName, Section, Setting, Values -Unique |
        Select-Object GPOName, Section, Setting, Values |
        Format-Table -Wrap
}
