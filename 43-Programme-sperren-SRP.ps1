#Requires -RunAsAdministrator
<#  43-Programme-sperren-SRP.ps1
    Eigenstaendiges Skript: sperrt einzelne Programme per Software Restriction
    Policies (SRP) als SCHWARZE LISTE. Standard ist "alles erlaubt", nur die
    Dateien aus $Sperrliste werden verboten (Browser-Umgebungen, KI- und
    Installer-Komponenten, winget usw. aus den Bildern).

    Die Sperre gilt fuer normale Nutzer, NICHT fuer Administratoren
    (PolicyScope = 1). So bleibt das Verwalter-Konto handlungsfaehig.

    Hinweis zur Abgrenzung: Das Hauptpaket nutzt AppLocker als echte WHITELIST
    (60-AppLocker-Einrichten.ps1) und ist damit strenger. SRP und AppLocker
    koennen kollidieren - laeuft der AppIDSvc, gewinnt AppLocker. Dieses Skript
    ist als leichtgewichtige, separate Sperre fuer einzelne Programme gedacht,
    wenn man KEINE volle Whitelist will. Beides gleichzeitig nicht empfohlen.

    Hinweis Store-Apps: Moderne Apps wie Fotos oder Karten laufen als UWP-Pakete,
    nicht als klassische EXE. SRP greift auf EXE-Namen; UWP blockiert man besser
    ueber AppLocker (Appx) oder Get-AppxPackage -AllUsers | Remove-AppxPackage.

    Beispiele:
      .\43-Programme-sperren-SRP.ps1                       # Sperrliste setzen
      .\43-Programme-sperren-SRP.ps1 -Entfernen            # Sperren wieder loesen
      .\43-Programme-sperren-SRP.ps1 -Sperrliste "foo.exe","bar.exe"

    Hinweis Ausfuehrung: Laeuft die PS1 nicht ("auf diesem System deaktiviert"),
    vorher in derselben Admin-PowerShell einmalig:
      Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

    Dieses Skript ist EIGENSTAENDIG: es braucht keine weiteren Dateien
    (kein _Common.ps1). Einfach diese eine Datei kopieren und ausfuehren.
#>
[CmdletBinding()]
param(
    [string[]]$Sperrliste = @(
        "winget.exe",
        "wingetmcpserver.exe",
        "webviewhost.exe",
        "appinstaller.exe",
        "appinstallerprotocolshim.exe",
        "appinstallerpythonredirector.exe",
        "msinfo32.exe",
        "createdump.exe",
        "maps.exe",
        "photos.exe",
        "photos.autoplay.exe",
        "wordpad.exe",
        "tutorial.exe",
        "maintenanceservice_installer.exe",
        "unins000.exe"
    ),
    [switch]$Entfernen
)
$ErrorActionPreference = 'Stop'

# --- Eigenstaendige Hilfsfunktionen (frueher aus _Common.ps1, hier eingebettet) ---
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

$log = Join-Path $env:USERPROFILE ("Lockdown-SRP-Sperrliste-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null

# SRP-Wurzel und die Stufe "Disallowed" (Level 0). Pfadregeln liegen unter \0\Paths\{GUID}.
$SaferBasis   = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers"
$DisallowProb = Join-Path $SaferBasis "0\Paths"   # 0 = Disallowed

try {
    if ($Entfernen) {
        Write-Schritt "SRP-Sperren entfernen"
        if (Test-Path $DisallowProb) {
            # Nur die von uns angelegten Regeln loeschen: deren ItemData steht in der Sperrliste.
            $entfernt = 0
            Get-ChildItem $DisallowProb -ErrorAction SilentlyContinue | ForEach-Object {
                $item = (Get-ItemProperty -Path $_.PSPath -Name ItemData -ErrorAction SilentlyContinue).ItemData
                if ($item -and ($Sperrliste -contains $item)) {
                    Remove-Item -Path $_.PSPath -Recurse -Force
                    Write-Ok "Regel entfernt: $item"
                    $entfernt++
                }
            }
            if ($entfernt -eq 0) { Write-Info "Keine passenden Regeln gefunden." }
        } else {
            Write-Info "Kein SRP-Regelpfad vorhanden, nichts zu entfernen."
        }
        Write-Info "Aktualisiere Richtlinien..."
        & gpupdate /force | Out-Null
        Write-Ok "Fertig. Sperren geloest. Protokoll: $log"
        return
    }

    Write-Schritt "Starte Blockierung von Browser-Umgebungen und KI-Komponenten"

    # 1) SRP-Grundzustand: schwarze Liste = standardmaessig alles erlaubt (Unrestricted),
    #    nur explizite Disallowed-Pfadregeln verbieten. Admins ausgenommen.
    Set-RegWert $SaferBasis "DefaultLevel"       "DWord"  262144   # 0x40000 = Unrestricted (Standard: erlaubt)
    Set-RegWert $SaferBasis "TransparentEnabled" "DWord"  1        # 1 = ohne DLLs (uebliche, performante Einstellung)
    Set-RegWert $SaferBasis "PolicyScope"        "DWord"  1        # 1 = Administratoren ausnehmen
    Set-RegWert $SaferBasis "authenticodeenabled" "DWord" 0
    # Dateitypen, auf die SRP wirkt (Standardsatz inkl. EXE)
    $exeTypen = @("ADE","ADP","BAS","BAT","CHM","CMD","COM","CPL","CRT","EXE","HLP","HTA",
                  "INF","INS","ISP","LNK","MDB","MDE","MSC","MSI","MSP","MST","OCX","PCD",
                  "PIF","REG","SCR","SHS","URL","VB","WSC")
    Set-RegWert $SaferBasis "ExecutableTypes" "MultiString" $exeTypen

    if (-not (Test-Path $DisallowProb)) { New-Item -Path $DisallowProb -Force | Out-Null }

    # 2) Vorhandene gleichnamige Regeln zuerst entfernen, damit das Skript ohne
    #    doppelte Eintraege wiederholt laufen kann (idempotent).
    Get-ChildItem $DisallowProb -ErrorAction SilentlyContinue | ForEach-Object {
        $item = (Get-ItemProperty -Path $_.PSPath -Name ItemData -ErrorAction SilentlyContinue).ItemData
        if ($item -and ($Sperrliste -contains $item)) { Remove-Item -Path $_.PSPath -Recurse -Force }
    }

    # 3) Fuer jede Datei eine Disallowed-Pfadregel anlegen
    foreach ($Datei in $Sperrliste) {
        $guid       = "{" + [Guid]::NewGuid().ToString() + "}"
        $regelPfad  = Join-Path $DisallowProb $guid
        New-Item -Path $regelPfad -Force | Out-Null

        # ItemData = der gesperrte Dateiname (Pfadregel ueber den Namen, greift ueberall).
        # SaferFlags = 0, Description zur Wiedererkennung.
        New-ItemProperty -Path $regelPfad -Name "ItemData"     -PropertyType ExpandString -Value $Datei -Force | Out-Null
        New-ItemProperty -Path $regelPfad -Name "SaferFlags"   -PropertyType DWord        -Value 0      -Force | Out-Null
        New-ItemProperty -Path $regelPfad -Name "Description"  -PropertyType String       -Value "Blockiert vom Lockdown-Skript 43-SRP" -Force | Out-Null
        New-ItemProperty -Path $regelPfad -Name "LastModified" -PropertyType QWord        -Value ([DateTime]::Now.ToFileTime()) -Force | Out-Null

        Write-Ok "Regel fuer $Datei wurde erstellt."
    }

    # 4) Richtlinie sofort anwenden
    Write-Info "Aktualisiere Richtlinien..."
    & gpupdate /force | Out-Null

    Write-Warn "SRP wirkt nicht fuer Administratoren (PolicyScope=1). Im Verwalter-Konto bleiben die Programme erlaubt."
    Write-Info  "Im normalen Nutzerkonto greifen die Sperren nach dem naechsten Anmelden."
    Write-Ok    "Fertig. $($Sperrliste.Count) Sperren aktiv. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
