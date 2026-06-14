#Requires -RunAsAdministrator
<#  00-Pruefung.ps1  Prueft Hardware und Zustand. Aendert nichts.  #>
[CmdletBinding()] param()
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_Common.ps1"
$log = Join-Path $env:USERPROFILE ("Lockdown-Pruefung-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null
try {
    Write-Schritt "Vorpruefung"
    Test-IstPro | Out-Null

    Write-Info "OS-Version: $((Get-CimInstance Win32_OperatingSystem).Version) (10.0.19045.x entspricht 22H2)"

    try {
        if (Confirm-SecureBootUEFI) { Write-Ok "Secure Boot ist aktiv" }
        else { Write-Warn "Secure Boot ist AUS. Im BIOS aktivieren." }
    } catch { Write-Warn "Secure Boot Status nicht lesbar (Legacy/CSM-Boot?). UEFI-Modus pruefen." }

    $tpm = Get-Tpm
    if ($tpm.TpmPresent -and $tpm.TpmReady) { Write-Ok "TPM vorhanden und einsatzbereit" }
    elseif ($tpm.TpmPresent) { Write-Warn "TPM vorhanden, aber nicht initialisiert. In tpm.msc 'TPM vorbereiten'." }
    else { Write-Warn "Kein nutzbares TPM. BitLocker nur mit Pre-Boot-Passwort oder USB-Startschluessel (siehe 20-BitLocker.ps1)." }

    Write-Info "BitLocker-Status und vorhandene Schluesselschutzvorrichtungen:"
    $bl = Get-BitLockerVolume -MountPoint $env:SystemDrive
    Write-Info "  Schutz: $($bl.ProtectionStatus), Status: $($bl.VolumeStatus)"
    $bl.KeyProtector | ForEach-Object { Write-Info "  - $($_.KeyProtectorType)" }

    $adminGrp = (Get-GruppeNachSid 'S-1-5-32-544').Name
    Write-Info "Mitglieder der Administratorengruppe:"
    Get-LocalGroupMember -Group $adminGrp | ForEach-Object { Write-Info "  - $($_.Name)" }

    Write-Info "Aktivierte Ausfuehrungsumgebungs-Features:"
    Get-WindowsOptionalFeature -Online |
        Where-Object { $_.State -eq 'Enabled' -and $_.FeatureName -match 'Linux|Hyper|Virtual|Sandbox|PowerShellV2' } |
        ForEach-Object { Write-Info "  - $($_.FeatureName)" }

    Write-Ok "Pruefung abgeschlossen. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
