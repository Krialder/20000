#Requires -RunAsAdministrator
<#  62-WDAC-Erzwingen.ps1
    Schaltet die Allowlist scharf (Audit-Modus entfernt). Erst ausfuehren, wenn der
    Audit sauber ist. Danach NEUSTART. Ab jetzt laeuft auch Admin-PowerShell im
    Constrained Language Mode, Wartung geht ueber den WinRE-Notausgang (siehe README).
#>
[CmdletBinding()]
param(
    [switch]$EntwicklungsumgebungErlaubt,
    [string]$WdacOrdner = 'C:\WDAC'
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_Common.ps1"
$log = Join-Path $env:USERPROFILE ("Lockdown-WDAC-Erzwingen-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null
try {
    Write-Schritt "WDAC im ERZWINGUNGS-Modus ausrollen"
    Build-WdacPolicy -EntwicklungsumgebungErlaubt:$EntwicklungsumgebungErlaubt -WdacOrdner $WdacOrdner
    Write-Ok "WDAC erzwungen. Neu starten. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
