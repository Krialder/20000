#Requires -RunAsAdministrator
<#  42-Edge-und-KI-deaktivieren.ps1
    Schaltet jede KI ab (Windows Copilot, Edge Copilot, Edge Shopping, Web-Suche im
    Startmenue) und neutralisiert Edge. Das eigentliche Sperren von Edge fuer den
    Nutzer macht AppLocker (60-AppLocker-Einrichten.ps1). Hier kommen die Richtlinien
    als zweite Sicherung dazu, plus optional die Deinstallation von Edge.

    Beispiele:
      .\42-Edge-und-KI-deaktivieren.ps1
      .\42-Edge-und-KI-deaktivieren.ps1 -EdgeDeinstallieren   # zusaetzlich Edge entfernen (siehe Hinweis)

    Hinweis Ausfuehrung: Laeuft die PS1 nicht ("auf diesem System deaktiviert"),
    vorher in derselben Admin-PowerShell einmalig:
      Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

    Dieses Skript ist EIGENSTAENDIG: keine weiteren Dateien noetig (kein _Common.ps1).
    Immer mit .\ davor starten, sonst deutet PowerShell den Namen als Rechnung.
#>
[CmdletBinding()]
param([switch]$EdgeDeinstallieren)
$ErrorActionPreference = 'Stop'

# --- Eigenstaendige Hilfsfunktionen ---
function Write-Schritt { param([string]$Text) Write-Host "[ $Text ]" -ForegroundColor Cyan }
function Write-Ok      { param([string]$Text) Write-Host "  OK   $Text" -ForegroundColor Green }
function Write-Warn    { param([string]$Text) Write-Host "  WARN $Text" -ForegroundColor Yellow }
function Write-Info    { param([string]$Text) Write-Host "       $Text" -ForegroundColor Gray }
function Set-RegWert {
    param([string]$Pfad,[string]$Name,[string]$Typ,$Wert)
    if (-not (Test-Path $Pfad)) { New-Item -Path $Pfad -Force | Out-Null }
    New-ItemProperty -Path $Pfad -Name $Name -PropertyType $Typ -Value $Wert -Force | Out-Null
    Write-Ok "$Pfad\$Name = $Wert"
}

$log = Join-Path $env:USERPROFILE ("Lockdown-EdgeKI-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null
try {
    Write-Schritt "KI deaktivieren und Edge neutralisieren"

    # --- Windows Copilot aus ---
    Set-RegWert "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" "DWord" 1
    Set-RegWert "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" "DWord" 1
    Set-RegWert "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" "DWord" 0

    # --- Web- und KI-Suche im Startmenue aus (Cortana, Bing) ---
    Set-RegWert "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" "DWord" 0
    Set-RegWert "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" "DWord" 1
    Set-RegWert "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb" "DWord" 0

    # --- Edge: Copilot, Sidebar, Shopping, Discover, Erststart aus ---
    $edge = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    Set-RegWert $edge "HubsSidebarEnabled"          "DWord" 0
    Set-RegWert $edge "StandaloneHubsSidebarEnabled" "DWord" 0
    Set-RegWert $edge "DiscoverEnabled"             "DWord" 0
    Set-RegWert $edge "EdgeShoppingAssistantEnabled" "DWord" 0
    Set-RegWert $edge "HideFirstRunExperience"      "DWord" 1
    Set-RegWert $edge "WebWidgetAllowed"            "DWord" 0     # Edge-Bar / Web-Widget aus
    Set-RegWert $edge "PromotionalTabsEnabled"      "DWord" 0

    # --- Edge soll sich nicht selbst neu installieren oder aktualisieren ---
    Set-RegWert "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate" "UpdateDefault" "DWord" 0
    Set-RegWert "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate" "InstallDefault" "DWord" 0

    Write-Ok "KI- und Edge-Richtlinien gesetzt"

    if ($EdgeDeinstallieren) {
        Write-Schritt "Edge deinstallieren"
        Write-Warn "Hinweis: Edge ist tief integriert. Die Deinstallation kann durch Updates rueckgaengig gemacht werden. AppLocker bleibt die verlaessliche Sperre."
        $setup = Get-ChildItem "C:\Program Files (x86)\Microsoft\Edge\Application\*\Installer\setup.exe" -ErrorAction SilentlyContinue |
                 Sort-Object FullName -Descending | Select-Object -First 1
        if ($setup) {
            & $setup.FullName --uninstall --system-level --verbose-logging --force-uninstall
            Write-Ok "Edge-Deinstallation angestossen"
        } else { Write-Warn "Edge-Setup nicht gefunden, Schritt uebersprungen." }
    } else {
        Write-Info "Edge wird nicht deinstalliert. Fuer den Nutzer sperrt AppLocker msedge.exe; WebView2 bleibt nutzbar."
    }

    Write-Ok "Fertig. Greift nach dem naechsten Anmelden. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
