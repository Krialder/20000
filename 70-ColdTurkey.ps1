#Requires -RunAsAdministrator
<#  70-ColdTurkey.ps1
    Richtet Cold Turkey Blocker als vollstaendige, gesperrte Zusatzschicht ein.
    Fuellt einen Block mit der Domainliste (coldturkey-domains.txt) und optional
    mit Apps, und startet ihn als gesperrten Timer.

    Cold Turkey hat keine vollstaendige Automatisierung. Per Kommandozeile gehen
    zuverlaessig nur das Befuellen und Starten eines Blocks. Die Selbstverteidigung
    (Block Task Manager, Registry Editor, Time settings, Safe Mode) und die
    Passwortsperre der Einstellungen werden EINMALIG in der Oberflaeche gesetzt,
    siehe README, Abschnitt Cold Turkey. Das ist die eigentliche Haertung.

    Voraussetzung: Cold Turkey Pro ist installiert (die Kommandozeile ist ein
    Pro-Feature). Block in der Oberflaeche einmal anlegen, hier Standardname "Kaufsperre".

    Beispiel:
      .\70-ColdTurkey.ps1 -BlockName "Kaufsperre" -StartLockMinuten 1440
#>
[CmdletBinding()]
param(
    [string]$ExePfad,
    [string]$BlockName = 'Kaufsperre',
    [string]$DomainDatei = "$PSScriptRoot\coldturkey-domains.txt",
    [string[]]$Apps = @('msedge.exe','chrome.exe','opera.exe','brave.exe','vivaldi.exe','tor.exe','steam.exe','epicgameslauncher.exe','copilot.exe'),  # Firefox bleibt erlaubt
    [int]$StartLockMinuten = 0    # 0 = nicht starten, nur befuellen; sonst gesperrter Timer in Minuten
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_Common.ps1"
$log = Join-Path $env:USERPROFILE ("Lockdown-ColdTurkey-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null
try {
    Write-Schritt "Cold Turkey als gesperrte Zusatzschicht"

    if (-not $ExePfad) {
        $kandidaten = @(
            "$env:ProgramFiles\Cold Turkey\Cold Turkey Blocker.exe",
            "${env:ProgramFiles(x86)}\Cold Turkey\Cold Turkey Blocker.exe"
        )
        $ExePfad = $kandidaten | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (-not $ExePfad -or -not (Test-Path $ExePfad)) {
        throw "Cold Turkey Blocker.exe nicht gefunden. Erst Cold Turkey Pro installieren und Block '$BlockName' in der Oberflaeche anlegen, dann -ExePfad angeben."
    }
    Write-Ok "Cold Turkey gefunden: $ExePfad"

    if (-not (Test-Path $DomainDatei)) { throw "Domainliste fehlt: $DomainDatei" }
    $domains = Get-Content $DomainDatei | Where-Object { $_ -and ($_ -notmatch '^\s*#') } | ForEach-Object { $_.Trim() }
    Write-Info "$($domains.Count) Domains werden dem Block '$BlockName' hinzugefuegt."

    foreach ($d in $domains) {
        & $ExePfad -add $BlockName -web $d 2>$null
    }
    Write-Ok "Domains hinzugefuegt"

    foreach ($a in $Apps) {
        & $ExePfad -add $BlockName -app $a 2>$null
    }
    Write-Ok "Apps gesperrt: $($Apps -join ', ')"

    if ($StartLockMinuten -gt 0) {
        & $ExePfad -start $BlockName -lock $StartLockMinuten 2>$null
        Write-Ok "Block '$BlockName' gestartet und fuer $StartLockMinuten Minuten gesperrt"
    } else {
        Write-Info "Block befuellt, aber nicht gestartet. Start ueber die Oberflaeche oder mit -StartLockMinuten."
    }

    Write-Warn "Jetzt EINMALIG in der Oberflaeche setzen (siehe README): Selbstverteidigung an,"
    Write-Warn "Einstellungen mit Passwort der Vertrauensperson sperren, gesperrten Zeitplan anlegen."
    Write-Ok "Cold Turkey abgeschlossen. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
