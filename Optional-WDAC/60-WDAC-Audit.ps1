#Requires -RunAsAdministrator
<#  60-WDAC-Audit.ps1
    Erstellt die Allowlist und rollt sie im AUDIT-Modus aus (nichts wird blockiert,
    nur protokolliert). Vorher BlockRules.xml und DriverBlockRules.xml von Microsoft
    Learn nach C:\WDAC legen. Danach NEUSTART, dann ein bis zwei Tage testen.
    Beispiel (Option B mit Entwicklungsumgebung):
      .\60-WDAC-Audit.ps1 -EntwicklungsumgebungErlaubt
#>
[CmdletBinding()]
param(
    [switch]$EntwicklungsumgebungErlaubt,
    [string]$WdacOrdner = 'C:\WDAC'
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_Common.ps1"
$log = Join-Path $env:USERPROFILE ("Lockdown-WDAC-Audit-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null
try {
    Write-Schritt "WDAC erstellen und im AUDIT-Modus ausrollen"
    Build-WdacPolicy -Audit -EntwicklungsumgebungErlaubt:$EntwicklungsumgebungErlaubt -WdacOrdner $WdacOrdner
    Write-Ok "WDAC-Audit abgeschlossen. Neu starten, dann 61-WDAC-Pruefen.ps1. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
