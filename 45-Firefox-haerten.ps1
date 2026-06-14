#Requires -RunAsAdministrator
<#  45-Firefox-haerten.ps1
    Installiert firefox-policies.json in den distribution-Ordner von Firefox.
    Damit sind KI aus, DoH aus, kein Passwort- und Formularspeicher, kein
    privates Surfen, about:config gesperrt, Erweiterungen gesperrt.

    Firefox muss installiert sein. Beispiel:
      .\45-Firefox-haerten.ps1
#>
[CmdletBinding()]
param([string]$PolicyDatei = "$PSScriptRoot\firefox-policies.json")
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_Common.ps1"
$log = Join-Path $env:USERPROFILE ("Lockdown-Firefox-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null
try {
    Write-Schritt "Firefox haerten"
    if (-not (Test-Path $PolicyDatei)) { throw "policies.json fehlt: $PolicyDatei" }

    $kandidaten = @(
        "$env:ProgramFiles\Mozilla Firefox\firefox.exe",
        "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
    )
    $exe = $kandidaten | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $exe) { throw "Firefox nicht gefunden. Erst Firefox installieren (als Admin, nach Program Files)." }
    Write-Ok "Firefox gefunden: $exe"

    $dist = Join-Path (Split-Path $exe) 'distribution'
    New-Item -ItemType Directory -Force -Path $dist | Out-Null
    Copy-Item $PolicyDatei (Join-Path $dist 'policies.json') -Force
    Write-Ok "policies.json installiert nach $dist"

    Write-Info "Pruefen: Firefox starten und about:policies oeffnen, dort muessen die Richtlinien als 'Aktiv' stehen."
    Write-Info "Firefox als Standardbrowser setzen: einmalig in Windows-Einstellungen, Apps, Standard-Apps, Firefox fuer http und https."
    Write-Info "DisableDeveloperTools steht auf false (Entwickler). Bei Bedarf in firefox-policies.json auf true setzen und Skript erneut laufen lassen."
    Write-Ok "Firefox abgeschlossen. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
