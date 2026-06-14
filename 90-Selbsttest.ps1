#Requires -RunAsAdministrator
<#  90-Selbsttest.ps1
    Prueft den erreichten Zustand und listet die Versuche auf, die im Alltagskonto
    von Hand scheitern muessen.
#>
[CmdletBinding()] param()
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_Common.ps1"
$log = Join-Path $env:USERPROFILE ("Lockdown-Selbsttest-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null
try {
    Write-Schritt "Selbsttest"

    $bl = Get-BitLockerVolume -MountPoint $env:SystemDrive
    if ($bl.ProtectionStatus -eq 'On') { Write-Ok "BitLocker: Schutz Ein ($($bl.VolumeStatus))" } else { Write-Warn "BitLocker: Schutz NICHT ein ($($bl.VolumeStatus))" }
    Write-Info "Aktive Protektoren: $(( $bl.KeyProtector | ForEach-Object { $_.KeyProtectorType }) -join ', ')"

    try {
        $dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard
        switch ($dg.CodeIntegrityPolicyEnforcementStatus) {
            2 { Write-Ok "WDAC: erzwungen" }
            1 { Write-Warn "WDAC: nur Audit-Modus" }
            default { Write-Warn "WDAC: keine Richtlinie aktiv" }
        }
    } catch { Write-Warn "WDAC-Status nicht lesbar" }

    foreach ($f in 'Microsoft-Windows-Subsystem-Linux','VirtualMachinePlatform','Microsoft-Hyper-V-All','MicrosoftWindowsPowerShellV2Root') {
        $s = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue
        if ($s -and $s.State -eq 'Enabled') { Write-Warn "$f ist noch AKTIV" } else { Write-Ok "$f deaktiviert oder nicht vorhanden" }
    }

    $ncu = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name NoConnectedUser -ErrorAction SilentlyContinue).NoConnectedUser
    if ($ncu) { Write-Ok "NoConnectedUser = $ncu" } else { Write-Warn "NoConnectedUser nicht gesetzt" }

    $ct = @("$env:ProgramFiles\Cold Turkey\Cold Turkey Blocker.exe","${env:ProgramFiles(x86)}\Cold Turkey\Cold Turkey Blocker.exe") | Where-Object { Test-Path $_ }
    if ($ct) { Write-Ok "Cold Turkey installiert" } else { Write-Warn "Cold Turkey nicht gefunden" }

    Write-Host ""
    Write-Info "Im Alltagskonto MUESSEN diese Versuche scheitern (von Hand testen):"
    Write-Info "  winget install Mozilla.Firefox        -> UAC und WDAC"
    Write-Info "  portable .exe aus Downloads starten   -> WDAC"
    Write-Info "  powershell -version 2                 -> Feature entfernt"
    Write-Info "  mshta.exe / regsvr32 Missbrauch       -> Sperrliste"
    Write-Info "  wsl.exe / VirtualBox starten          -> Feature aus / WDAC"
    Write-Info "  Kauf per Skript an Haendler-API       -> Router-Default-Deny und keine Zahlung"
    Write-Info "  Live-USB / abgesicherter Modus        -> BIOS-Sperre und BitLocker"
    Write-Info "  fremdes Microsoft-Konto hinzufuegen   -> NoConnectedUser"
    Write-Info "  Shopping-Domain im erlaubten Browser  -> Cold Turkey"
    Write-Ok "Selbsttest abgeschlossen. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
