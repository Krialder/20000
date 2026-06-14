#Requires -RunAsAdministrator
<#  60-AppLocker-Einrichten.ps1
    Richtet die AppLocker-WHITELIST aus AppLocker-Policy.xml ein.
    Fuer das verwaltete Konto laeuft nur, was ausdruecklich erlaubt ist (Windows,
    Firefox, eingetragene Arbeitsprogramme). Alles andere ist gesperrt.

    Benoetigte Arbeitsprogramme VORHER mit 63-AppLocker-Programm-erlauben.ps1
    aufnehmen, sonst starten sie im verwalteten Konto nicht.

    Standard ist der Audit-Modus (nichts wird blockiert, nur protokolliert).
    Mit -Erzwingen wird scharf geschaltet, mit -DllRegeln zusaetzlich die DLL-Pruefung.

    Schritte: AppIDSvc auf Automatisch, SID des verwalteten Kontos ermitteln,
    Platzhalter in der XML ersetzen, Richtlinie setzen, Stand anzeigen.

    Beispiele:
      .\60-AppLocker-Einrichten.ps1 -StandardKonto "Alltag"                 # Audit
      .\60-AppLocker-Einrichten.ps1 -StandardKonto "Alltag" -Erzwingen      # scharf
      .\60-AppLocker-Einrichten.ps1 -StandardKonto "Alltag" -Erzwingen -DllRegeln
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$StandardKonto,
    [switch]$Erzwingen,
    [switch]$DllRegeln,
    [string]$PolicyVorlage = "$PSScriptRoot\AppLocker-Policy.xml"
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_Common.ps1"
$log = Join-Path $env:USERPROFILE ("Lockdown-AppLocker-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null
try {
    Write-Schritt "AppLocker einrichten"

    if (-not (Test-Path $PolicyVorlage)) { throw "Vorlage fehlt: $PolicyVorlage" }

    # 1) AppIDSvc auf Automatisch (geschuetzter Dienst, daher ueber sc.exe und Registry)
    Write-Info "Application Identity Service (AppIDSvc) auf Automatisch setzen"
    & sc.exe config appidsvc start= auto | Out-Null
    Set-RegWert "HKLM:\SYSTEM\CurrentControlSet\Services\AppIDSvc" "Start" "DWord" 2
    try { Start-Service appidsvc -ErrorAction Stop; Write-Ok "AppIDSvc laeuft" }
    catch { Write-Warn "AppIDSvc startet erst nach einem Neustart. Das ist normal." }

    # 2) SID des verwalteten Kontos ermitteln
    $sid = (New-Object System.Security.Principal.NTAccount($StandardKonto)).Translate([System.Security.Principal.SecurityIdentifier]).Value
    Write-Ok "Verwaltetes Konto '$StandardKonto' hat SID $sid"

    # 3) Modus bestimmen
    $mode    = if ($Erzwingen) { 'Enabled' } else { 'AuditOnly' }
    $dllMode = if ($DllRegeln) { if ($Erzwingen) { 'Enabled' } else { 'AuditOnly' } } else { 'NotConfigured' }
    Write-Info "Exe/Script/Msi/Appx: $mode   Dll: $dllMode"

    # 4) Platzhalter ersetzen und temporaere XML schreiben
    $xml = Get-Content $PolicyVorlage -Raw
    $xml = $xml.Replace('__MODE__', $mode).Replace('__DLLMODE__', $dllMode).Replace('__SID__', $sid)
    $temp = Join-Path $env:TEMP 'AppLocker-Effektiv.xml'
    $xml | Out-File -FilePath $temp -Encoding utf8 -Force

    # 5) Richtlinie setzen (ersetzt die lokale AppLocker-Richtlinie)
    Set-AppLockerPolicy -XmlPolicy $temp
    Write-Ok "AppLocker-Richtlinie gesetzt"

    if ($Erzwingen) {
        Write-Warn "Scharf geschaltet. Vorher im Audit-Modus getestet haben. Jetzt neu starten."
    } else {
        Write-Info "Audit-Modus aktiv. Ein bis zwei Tage testen, dann 61-AppLocker-Pruefen.ps1, dann mit -Erzwingen scharf schalten."
    }
    Write-Info "Wirksamer Stand:"
    (Get-AppLockerPolicy -Effective).RuleCollections | ForEach-Object { Write-Info "  $($_.RuleCollectionType): $($_.EnforcementMode), $($_.Count) Regeln" }
    Write-Ok "AppLocker abgeschlossen. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
