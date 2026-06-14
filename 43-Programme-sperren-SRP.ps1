#Requires -RunAsAdministrator
<#  43-Programme-sperren-SRP.ps1
    Eigenstaendiges Skript: sperrt einzelne Programme per Software Restriction
    Policies (SRP) als SCHWARZE LISTE. Standard ist "alles erlaubt", nur die
    Dateien aus der Sperrliste werden verboten (Browser-Umgebungen, KI- und
    Installer-Komponenten, winget, WordPad usw.).

    Die Sperre gilt fuer normale Nutzer, NICHT fuer Administratoren
    (PolicyScope = 1). Im Verwalter-Konto bleiben die Programme erlaubt.
    Wichtig: Als Admin testen bedeutet, dass die Sperre scheinbar nicht wirkt.
    Im normalen Nutzerkonto nach erneutem Anmelden testen.

    Das Skript loest jeden Dateinamen zum vollen Pfad auf, bevor es die
    SRP-Pfadregel anlegt. Nur ein voller Pfad blockiert SRP zuverlaessig;
    ein blosser Dateiname ("wordpad.exe") greift in SRP nicht.

    Hinweis zur Abgrenzung: Das Hauptpaket nutzt AppLocker als echte WHITELIST
    (60-AppLocker-Einrichten.ps1) und ist damit strenger. SRP und AppLocker
    koennen kollidieren - laeuft der AppIDSvc, gewinnt AppLocker. Dieses Skript
    ist als leichtgewichtige, separate Sperre fuer einzelne Programme gedacht,
    wenn man KEINE volle Whitelist will. Beides gleichzeitig nicht empfohlen.

    Hinweis Store-Apps: Moderne Apps wie Fotos oder Karten laufen als UWP-Pakete.
    Diese blockiert man besser ueber AppLocker (Appx-Regeln) oder per
    Get-AppxPackage | Remove-AppxPackage.

    Beispiele:
      .\43-Programme-sperren-SRP.ps1                          # Sperrliste setzen
      .\43-Programme-sperren-SRP.ps1 -Entfernen               # Sperren loesen
      .\43-Programme-sperren-SRP.ps1 -Sperrliste "foo.exe"

    Hinweis Ausfuehrung: Laeuft die PS1 nicht ("auf diesem System deaktiviert"),
    vorher in derselben Admin-PowerShell einmalig:
      Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

    Dieses Skript ist EIGENSTAENDIG: keine weiteren Dateien noetig.
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

# Loest einen EXE-Namen in den vollen Pfad auf. Suchreihenfolge: PATH,
# bekannte Windows-Orte, %LOCALAPPDATA%\Microsoft\WindowsApps (winget).
function Resolve-ExePfad {
    param([string]$Name)
    # 1) Schon ein Pfad?
    if ([System.IO.Path]::IsPathRooted($Name) -and (Test-Path $Name)) { return $Name }
    # 2) Im PATH oder via Get-Command
    $gc = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($gc) { return $gc.Source }
    # 3) Typische Windows-Ordner absuchen
    $suchOrdner = @(
        "$env:ProgramFiles",
        "${env:ProgramFiles(x86)}",
        "$env:SystemRoot\System32",
        "$env:SystemRoot\SysWOW64",
        "$env:SystemRoot",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps",
        "$env:ProgramFiles\Windows NT\Accessories"   # WordPad
    )
    foreach ($ordner in $suchOrdner) {
        if (-not $ordner) { continue }
        $kandidat = Join-Path $ordner $Name
        if (Test-Path $kandidat) { return $kandidat }
        # Einmalig eine Ebene tiefer (z.B. WindowsApps-Unterordner fuer winget)
        $treffer = Get-ChildItem -Path $ordner -Filter $Name -Recurse -Depth 2 -ErrorAction SilentlyContinue |
                   Select-Object -First 1
        if ($treffer) { return $treffer.FullName }
    }
    return $null
}

$log = Join-Path $env:USERPROFILE ("Lockdown-SRP-Sperrliste-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null

$SaferBasis   = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers"
$DisallowProb = Join-Path $SaferBasis "0\Paths"

try {
    if ($Entfernen) {
        Write-Schritt "SRP-Sperren entfernen"
        if (Test-Path $DisallowProb) {
            $entfernt = 0
            Get-ChildItem $DisallowProb -ErrorAction SilentlyContinue | ForEach-Object {
                $desc = (Get-ItemProperty -Path $_.PSPath -Name Description -ErrorAction SilentlyContinue).Description
                if ($desc -eq "Blockiert vom Lockdown-Skript 43-SRP") {
                    $item = (Get-ItemProperty -Path $_.PSPath -Name ItemData -ErrorAction SilentlyContinue).ItemData
                    Remove-Item -Path $_.PSPath -Recurse -Force
                    Write-Ok "Regel entfernt: $item"
                    $entfernt++
                }
            }
            if ($entfernt -eq 0) { Write-Info "Keine passenden Regeln gefunden." }
        } else {
            Write-Info "Kein SRP-Regelpfad vorhanden, nichts zu entfernen."
        }
        & gpupdate /force | Out-Null
        Write-Ok "Fertig. Sperren geloest. Protokoll: $log"
        return
    }

    Write-Schritt "SRP-Sperrliste setzen"

    # SRP-Grundzustand: schwarze Liste, Admins ausgenommen
    Set-RegWert $SaferBasis "DefaultLevel"        "DWord" 262144  # Unrestricted
    Set-RegWert $SaferBasis "TransparentEnabled"  "DWord" 1
    Set-RegWert $SaferBasis "PolicyScope"         "DWord" 1       # Admins ausgenommen
    Set-RegWert $SaferBasis "authenticodeenabled" "DWord" 0
    $exeTypen = @("ADE","ADP","BAS","BAT","CHM","CMD","COM","CPL","CRT","EXE","HLP","HTA",
                  "INF","INS","ISP","LNK","MDB","MDE","MSC","MSI","MSP","MST","OCX","PCD",
                  "PIF","REG","SCR","SHS","URL","VB","WSC")
    Set-RegWert $SaferBasis "ExecutableTypes" "MultiString" $exeTypen

    if (-not (Test-Path $DisallowProb)) { New-Item -Path $DisallowProb -Force | Out-Null }

    # Vorhandene eigene Regeln zuerst entfernen (idempotent)
    Get-ChildItem $DisallowProb -ErrorAction SilentlyContinue | ForEach-Object {
        $desc = (Get-ItemProperty -Path $_.PSPath -Name Description -ErrorAction SilentlyContinue).Description
        if ($desc -eq "Blockiert vom Lockdown-Skript 43-SRP") { Remove-Item -Path $_.PSPath -Recurse -Force }
    }

    $gesperrt  = 0
    $nichtGef  = @()

    foreach ($Datei in $Sperrliste) {
        $vollerPfad = Resolve-ExePfad -Name $Datei
        if (-not $vollerPfad) {
            Write-Warn "Nicht gefunden (uebersprungen): $Datei"
            $nichtGef += $Datei
            continue
        }

        $guid      = "{" + [Guid]::NewGuid().ToString() + "}"
        $regelPfad = Join-Path $DisallowProb $guid
        New-Item -Path $regelPfad -Force | Out-Null
        New-ItemProperty -Path $regelPfad -Name "ItemData"     -PropertyType ExpandString -Value $vollerPfad -Force | Out-Null
        New-ItemProperty -Path $regelPfad -Name "SaferFlags"   -PropertyType DWord        -Value 0           -Force | Out-Null
        New-ItemProperty -Path $regelPfad -Name "Description"  -PropertyType String       -Value "Blockiert vom Lockdown-Skript 43-SRP" -Force | Out-Null
        New-ItemProperty -Path $regelPfad -Name "LastModified" -PropertyType QWord        -Value ([DateTime]::Now.ToFileTime()) -Force | Out-Null

        Write-Ok "$Datei  ->  $vollerPfad"
        $gesperrt++
    }

    Write-Info "Aktualisiere Richtlinien..."
    & gpupdate /force | Out-Null

    Write-Warn "Sperre gilt NUR im normalen Nutzerkonto (PolicyScope=1 = Admins frei)."
    Write-Warn "Als Verwalter testen zeigt keine Wirkung. Im Alltags-Konto nach Neuanmelden pruefen."
    if ($nichtGef.Count -gt 0) {
        Write-Warn "Nicht auf dem Geraet gefunden (keine Regel angelegt): $($nichtGef -join ', ')"
    }
    Write-Ok "Fertig. $gesperrt Sperren aktiv. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
