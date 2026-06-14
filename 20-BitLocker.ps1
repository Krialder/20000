#Requires -RunAsAdministrator
<#  20-BitLocker.ps1
    Verschluesselt das Systemlaufwerk. Unterstuetzt TPM und, da euer Laptop kein
    nutzbares TPM hat, auch BitLocker OHNE TPM.

    Modi:
      Auto                 TPM falls einsatzbereit, sonst PasswortOhneTpm
      Tpm                  TPM-Protektor, unbeaufsichtigter Start
      PasswortOhneTpm      Pre-Boot-Passwort, Eingabe bei JEDEM Start noetig
      UsbSchluesselOhneTpm USB-Startschluessel, Stick bei JEDEM Start noetig

    Beispiele:
      .\20-BitLocker.ps1 -Modus PasswortOhneTpm -SchluesselDatei "E:\BitLocker-Schluessel.txt"
      .\20-BitLocker.ps1 -Modus UsbSchluesselOhneTpm -StartupKeyLaufwerk "F:"

    WICHTIG ohne TPM: Wer das Pre-Boot-Geheimnis kennt, bestimmt den Schutz.
      - Geheimnis bei der Vertrauensperson: voller Offline-Schutz, aber sie muss
        bei jedem Start dabei sein.
      - Geheimnis bei der betroffenen Person: sie startet allein, der Offline-
        Angriff auf die ausgebaute Platte bleibt aber offen. Alle uebrigen
        Schichten (Standardkonto, WDAC, Zahlung, Router, Cold Turkey) greifen
        im laufenden Betrieb trotzdem.
#>
[CmdletBinding()]
param(
    [ValidateSet('Auto','Tpm','PasswortOhneTpm','UsbSchluesselOhneTpm')]
    [string]$Modus = 'Auto',
    [string]$SchluesselDatei = "$env:USERPROFILE\Desktop\BitLocker-Wiederherstellungsschluessel.txt",
    [string]$StartupKeyLaufwerk
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_Common.ps1"
$log = Join-Path $env:USERPROFILE ("Lockdown-BitLocker-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null
try {
    $laufwerk = $env:SystemDrive
    $tpm = Get-Tpm
    $tpmReady = $tpm.TpmPresent -and $tpm.TpmReady

    if ($Modus -eq 'Auto') {
        if ($tpmReady) { $Modus = 'Tpm'; Write-Ok "TPM einsatzbereit, Modus Tpm gewaehlt" }
        else { $Modus = 'PasswortOhneTpm'; Write-Warn "Kein einsatzbereites TPM, Modus PasswortOhneTpm gewaehlt" }
    }
    Write-Schritt "BitLocker einrichten (Modus: $Modus)"

    $vol = Get-BitLockerVolume -MountPoint $laufwerk
    $schonAktiv = ($vol.ProtectionStatus -eq 'On') -or ($vol.VolumeStatus -ne 'FullyDecrypted')

    if ($schonAktiv) {
        Write-Info "BitLocker ist bereits aktiv oder laeuft. Es wird nur der Wiederherstellungsschluessel sichergestellt."
    } else {
        switch ($Modus) {
            'Tpm' {
                if (-not $tpmReady) { throw "Modus Tpm, aber kein einsatzbereites TPM. tpm.msc pruefen oder anderen Modus waehlen." }
                Enable-BitLocker -MountPoint $laufwerk -EncryptionMethod XtsAes256 -UsedSpaceOnly -TpmProtector -SkipHardwareTest | Out-Null
                Write-Ok "BitLocker mit TPM-Protektor gestartet (unbeaufsichtigter Start)"
            }
            'PasswortOhneTpm' {
                Set-FveOhneTpm -Passwort
                $pp = Read-Host "Pre-Boot-Passwort (Eingabe bei JEDEM Start noetig)" -AsSecureString
                try {
                    Enable-BitLocker -MountPoint $laufwerk -EncryptionMethod XtsAes256 -UsedSpaceOnly -PasswordProtector -Password $pp | Out-Null
                    Write-Ok "BitLocker mit Pre-Boot-Passwort gestartet"
                } catch {
                    Write-Warn "Cmdlet-Weg abgelehnt ($($_.Exception.Message)). Fallback ueber manage-bde, bitte Passwort erneut eingeben:"
                    manage-bde -on $laufwerk -pw
                }
            }
            'UsbSchluesselOhneTpm' {
                if (-not $StartupKeyLaufwerk) { throw "Bitte -StartupKeyLaufwerk angeben, z.B. F:" }
                Set-FveOhneTpm -UsbKey
                Enable-BitLocker -MountPoint $laufwerk -EncryptionMethod XtsAes256 -UsedSpaceOnly -StartupKeyProtector -StartupKeyPath $StartupKeyLaufwerk | Out-Null
                Write-Ok "BitLocker mit USB-Startschluessel auf $StartupKeyLaufwerk gestartet"
            }
        }
    }

    # Wiederherstellungsschluessel sicherstellen und ausgeben
    $vol = Get-BitLockerVolume -MountPoint $laufwerk
    if (-not ($vol.KeyProtector | Where-Object KeyProtectorType -eq 'RecoveryPassword')) {
        Add-BitLockerKeyProtector -MountPoint $laufwerk -RecoveryPasswordProtector | Out-Null
        Write-Ok "Wiederherstellungsschluessel hinzugefuegt"
    }
    $rp = (Get-BitLockerVolume -MountPoint $laufwerk).KeyProtector | Where-Object KeyProtectorType -eq 'RecoveryPassword'

    $inhalt = @"
BitLocker Wiederherstellungsschluessel fuer $laufwerk
Geraet: $env:COMPUTERNAME   Modus: $Modus
Erstellt: $(Get-Date -Format 'yyyy-MM-dd HH:mm')

Schluessel-ID:     $($rp.KeyProtectorId)
Wiederherstellung: $($rp.RecoveryPassword)

Ausschliesslich bei der Vertrauensperson verwahren. Dies ist der Notausgang
fuer Wartung in WinRE und zugleich der Schluessel, der die betroffene Person
nicht erreichen darf.
"@
    try { $inhalt | Out-File -FilePath $SchluesselDatei -Encoding utf8 -Force; Write-Ok "Schluessel gespeichert: $SchluesselDatei" }
    catch { Write-Warn "Konnte Schluessel nicht in '$SchluesselDatei' schreiben. Bitte manuell notieren." }

    Write-Host ""
    Write-Host "  Wiederherstellungsschluessel: $($rp.RecoveryPassword)" -ForegroundColor Magenta
    Write-Host ""
    Write-Info "Status (auf 'Schutz: Ein' und 100 Prozent warten):"
    manage-bde -status $laufwerk
    Write-Ok "BitLocker abgeschlossen. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
