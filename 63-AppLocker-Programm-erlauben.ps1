#Requires -RunAsAdministrator
<#  63-AppLocker-Programm-erlauben.ps1
    Nimmt ein benoetigtes Programm in die Whitelist (AppLocker-Policy.xml) auf.
    Erzeugt bevorzugt Herausgeber-Regeln (ueberleben Updates), mit Hash-Rueckfall
    fuer unsignierte Dateien (muessen nach jedem Update neu erlaubt werden).

    Reihenfolge: erst Programm sauber als Admin nach Program Files installieren,
    dann dieses Skript auf den Ordner oder die EXE zeigen lassen, dann
    60-AppLocker-Einrichten.ps1 erneut ausfuehren.

    Beispiele:
      .\63-AppLocker-Programm-erlauben.ps1 -Pfad "C:\Program Files\Mozilla Firefox"
      .\63-AppLocker-Programm-erlauben.ps1 -Pfad "C:\Program Files\Git","C:\Program Files\Notepad++" -MitDll
      .\63-AppLocker-Programm-erlauben.ps1 -Pfad "C:\Program Files\Tool\tool.exe" -Bevorzugt Hash
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$Pfad,
    [switch]$MitDll,
    [ValidateSet('Publisher','Hash')][string]$Bevorzugt = 'Publisher',
    [string]$PolicyDatei = "$PSScriptRoot\AppLocker-Policy.xml"
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_Common.ps1"
$log = Join-Path $env:USERPROFILE ("Lockdown-AppLocker-Erlauben-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null
try {
    Write-Schritt "Programm in die Whitelist aufnehmen"
    if (-not (Test-Path $PolicyDatei)) { throw "Policy fehlt: $PolicyDatei" }

    $ft = if ($MitDll) { @('Exe','Dll') } else { @('Exe') }
    $fi = foreach ($p in $Pfad) {
        if (Test-Path $p -PathType Container) {
            Write-Info "Scanne Ordner: $p"
            Get-AppLockerFileInformation -Directory $p -Recurse -FileType $ft
        } elseif (Test-Path $p) {
            Write-Info "Datei: $p"
            Get-AppLockerFileInformation -Path $p
        } else { Write-Warn "Pfad fehlt, uebersprungen: $p" }
    }
    if (-not $fi) { throw "Keine Dateien gefunden." }

    $ruleTypes = if ($Bevorzugt -eq 'Publisher') { @('Publisher','Hash') } else { @('Hash') }
    $gen = New-AppLockerPolicy -FileInformation $fi -RuleType $ruleTypes -User Everyone -Optimize -IgnoreMissingFileInformation
    $genXml = [xml]$gen.ToXml()

    # Basis-XML laden, Formatierung erhalten
    $base = New-Object System.Xml.XmlDocument
    $base.PreserveWhitespace = $true
    $base.Load((Resolve-Path $PolicyDatei).Path)

    $hinzugefuegt = 0; $hashRegeln = 0
    foreach ($coll in $genXml.AppLockerPolicy.RuleCollection) {
        $baseColl = $base.AppLockerPolicy.RuleCollection | Where-Object { $_.Type -eq $coll.Type }
        if (-not $baseColl) { continue }
        foreach ($rule in $coll.ChildNodes) {
            if ($rule.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
            $imp = $base.ImportNode($rule, $true)
            # Herausgeber-Regeln versionsunabhaengig machen, damit Updates weiter laufen
            foreach ($vr in $imp.SelectNodes('.//BinaryVersionRange')) {
                $vr.SetAttribute('LowSection','*'); $vr.SetAttribute('HighSection','*')
            }
            if ($imp.LocalName -eq 'FileHashRule') { $hashRegeln++ }
            [void]$baseColl.AppendChild($imp)
            $hinzugefuegt++
        }
    }
    $base.Save((Resolve-Path $PolicyDatei).Path)

    Write-Ok "$hinzugefuegt Regeln in $PolicyDatei eingetragen"
    if ($hashRegeln -gt 0) { Write-Warn "$hashRegeln davon sind Hash-Regeln (unsignierte Dateien). Diese nach jedem Update des Programms erneut erzeugen." }
    Write-Info "Jetzt 60-AppLocker-Einrichten.ps1 erneut ausfuehren, damit die Aenderung wirkt."
    Write-Ok "Fertig. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
