#Requires -RunAsAdministrator
<#  30-Haertung.ps1
    Setzt die Registry-Haertung: fremde Microsoft-Konten sperren, Edge gegen
    eigenes DoH, InPrivate und Profilwechsel.
    Beispiel:  .\30-Haertung.ps1 -NoConnectedUser 1
#>
[CmdletBinding()]
param(
    [ValidateSet(1,3)]
    [int]$NoConnectedUser = 1   # 1 = fremde MS-Konten sperren, verwaltetes bleibt; 3 = rein lokaler Weg
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_Common.ps1"
$log = Join-Path $env:USERPROFILE ("Lockdown-Haertung-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null
try {
    Write-Schritt "Systemhaertung ueber die Registry"

    Set-RegWert "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "NoConnectedUser" "DWord" $NoConnectedUser

    $edge = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    Set-RegWert $edge "BuiltInDnsClientEnabled"   "DWord" 0
    Set-RegWert $edge "DnsOverHttpsMode"          "String" "off"
    Set-RegWert $edge "InPrivateModeAvailability" "DWord" 1
    Set-RegWert $edge "BrowserAddProfileEnabled"  "DWord" 0
    Set-RegWert $edge "BrowserGuestModeEnabled"   "DWord" 0

    Write-Info "Greift nach dem naechsten Anmelden. Ausfuehrung von Wechseldatentraegern blockt WDAC."
    Write-Ok "Haertung abgeschlossen. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
