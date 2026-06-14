#Requires -RunAsAdministrator
<#  10-Konten.ps1
    Legt Admin- und Standardkonto an und stuft das Alltagskonto auf Standardbenutzer herab.
    Beispiele:
      .\10-Konten.ps1 -AdminKonto "Verwalter" -StandardKonto "Alltag"
      .\10-Konten.ps1 -HerabstufenKonto "Alltag"
#>
[CmdletBinding()]
param(
    [string]$AdminKonto,
    [string]$StandardKonto,
    [string]$HerabstufenKonto
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_Common.ps1"
$log = Join-Path $env:USERPROFILE ("Lockdown-Konten-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null
try {
    Write-Schritt "Konten einrichten"
    $adminGrp = (Get-GruppeNachSid 'S-1-5-32-544').Name
    $userGrp  = (Get-GruppeNachSid 'S-1-5-32-545').Name

    if ($AdminKonto) {
        if (-not (Get-LocalUser -Name $AdminKonto -ErrorAction SilentlyContinue)) {
            $pw = Read-Host "Passwort fuer Adminkonto '$AdminKonto' (nur Vertrauensperson)" -AsSecureString
            New-LocalUser -Name $AdminKonto -Password $pw -FullName $AdminKonto -Description "Verwaltung Vertrauensperson" -PasswordNeverExpires | Out-Null
            Write-Ok "Adminkonto '$AdminKonto' angelegt"
        } else { Write-Info "Adminkonto '$AdminKonto' existiert bereits" }
        if (-not (Get-LocalGroupMember -Group $adminGrp -Member $AdminKonto -ErrorAction SilentlyContinue)) {
            Add-LocalGroupMember -Group $adminGrp -Member $AdminKonto
            Write-Ok "'$AdminKonto' zur Administratorengruppe hinzugefuegt"
        }
    }

    if ($StandardKonto) {
        if (-not (Get-LocalUser -Name $StandardKonto -ErrorAction SilentlyContinue)) {
            $pw = Read-Host "Passwort fuer Standardkonto '$StandardKonto'" -AsSecureString
            New-LocalUser -Name $StandardKonto -Password $pw -FullName $StandardKonto -Description "Alltagskonto, Standardbenutzer" -PasswordNeverExpires | Out-Null
            Write-Ok "Standardkonto '$StandardKonto' angelegt"
        } else { Write-Info "Standardkonto '$StandardKonto' existiert bereits" }
        if (Get-LocalGroupMember -Group $adminGrp -Member $StandardKonto -ErrorAction SilentlyContinue) {
            Remove-LocalGroupMember -Group $adminGrp -Member $StandardKonto
            Write-Ok "'$StandardKonto' aus der Administratorengruppe entfernt"
        }
        if (-not (Get-LocalGroupMember -Group $userGrp -Member $StandardKonto -ErrorAction SilentlyContinue)) {
            Add-LocalGroupMember -Group $userGrp -Member $StandardKonto
        }
    }

    if ($HerabstufenKonto) {
        $verbleibend = Get-LocalGroupMember -Group $adminGrp | Where-Object { $_.Name -notmatch [regex]::Escape($HerabstufenKonto) }
        if (-not $verbleibend) { throw "Abbruch: '$HerabstufenKonto' ist der einzige Administrator. Erst -AdminKonto anlegen, sonst Aussperrung." }
        if (Get-LocalGroupMember -Group $adminGrp -Member $HerabstufenKonto -ErrorAction SilentlyContinue) {
            Remove-LocalGroupMember -Group $adminGrp -Member $HerabstufenKonto
            Write-Ok "'$HerabstufenKonto' auf Standardbenutzer herabgestuft"
        } else { Write-Info "'$HerabstufenKonto' ist bereits kein Administrator" }
    }

    Write-Info "Stand der Administratorengruppe:"
    Get-LocalGroupMember -Group $adminGrp | ForEach-Object { Write-Info "  - $($_.Name)" }
    Write-Ok "Konten abgeschlossen. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
