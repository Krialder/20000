#Requires -RunAsAdministrator
<#  50-Dns.ps1
    Setzt einen gefilterten DNS am Geraet. Ergaenzung, nicht Ersatz fuer den Router.
    Beispiel:  .\50-Dns.ps1 -DnsServer "1.1.1.3","1.0.0.3"
#>
[CmdletBinding()]
param([string[]]$DnsServer = @('1.1.1.3','1.0.0.3'))   # Cloudflare Families (Malware + Adult)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_Common.ps1"
$log = Join-Path $env:USERPROFILE ("Lockdown-Dns-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null
try {
    Write-Schritt "Gefilterten DNS am Geraet setzen"
    foreach ($a in (Get-NetAdapter | Where-Object Status -eq 'Up')) {
        Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses $DnsServer
        Write-Ok "$($a.Name): DNS = $($DnsServer -join ', ')"
    }
    Write-Info "Ein Standardnutzer kann diese Adaptereinstellung ohne Adminrechte nicht aendern."
    Write-Warn "DNS-Filter sind nur Reibung. Wirksam gegen einen Entwickler ist erst das ausgehende Default-Deny am Router."
    Write-Ok "DNS abgeschlossen. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
