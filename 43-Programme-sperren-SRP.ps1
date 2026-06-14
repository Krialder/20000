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

    Pfadaufloesung: Das Skript loest jeden Dateinamen zum vollen Pfad auf, denn
    nur ein voller Pfad blockiert SRP zuverlaessig. Erst werden bekannte Orte
    schnell geprueft; was dort fehlt, wird per Tiefenscan ueber ALLE Laufwerke
    gesucht (inkl. C:\Program Files\WindowsApps). Versionierte WindowsApps-Pfade
    werden zu einer Wildcard verallgemeinert, damit die Regel Updates ueberlebt.

    Hinweis Store-Apps: Moderne Apps wie Fotos oder Karten laufen als UWP-Pakete.
    SRP blockiert UWP nicht zuverlaessig. Diese besser ueber AppLocker (Appx)
    oder per Get-AppxPackage | Remove-AppxPackage entfernen. Der echte Name der
    Fotos-App ist z.B. "Microsoft.Photos.exe", nicht "photos.exe".

    Hinweis zur Abgrenzung: Das Hauptpaket nutzt AppLocker als echte WHITELIST
    (60-AppLocker-Einrichten.ps1) und ist damit strenger. SRP und AppLocker
    koennen kollidieren - laeuft der AppIDSvc, gewinnt AppLocker.

    Beispiele:
      .\43-Programme-sperren-SRP.ps1                 # bekannte Orte + Tiefenscan fuer Fehlende
      .\43-Programme-sperren-SRP.ps1 -Tiefenscan     # alle Namen per Tiefenscan (auch Mehrfachorte)
      .\43-Programme-sperren-SRP.ps1 -SchnellNur     # nur bekannte Orte, kein Tiefenscan
      .\43-Programme-sperren-SRP.ps1 -Entfernen      # Sperren loesen
      .\43-Programme-sperren-SRP.ps1 -Sperrliste "foo.exe"

    Hinweis Ausfuehrung: Laeuft die PS1 nicht ("auf diesem System deaktiviert"),
    vorher in derselben Admin-PowerShell einmalig:
      Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

    WICHTIG: Skript immer mit  .\  davor starten (.\43-...ps1). Ohne .\ deutet
    PowerShell den mit Ziffer beginnenden Namen als Rechnung -> Parserfehler.
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
    [switch]$Entfernen,
    [switch]$Tiefenscan,
    [switch]$SchnellNur
)
$ErrorActionPreference = 'Stop'

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

# Schnelle Aufloesung ueber bekannte Orte. Gibt den ersten Treffer zurueck oder $null.
function Resolve-Schnell {
    param([string]$Name)
    if ([System.IO.Path]::IsPathRooted($Name) -and (Test-Path $Name)) { return $Name }
    $gc = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($gc -and $gc.Source) { return $gc.Source }
    $orte = @(
        "$env:SystemRoot\System32","$env:SystemRoot\SysWOW64","$env:SystemRoot",
        "$env:ProgramFiles","${env:ProgramFiles(x86)}",
        "$env:ProgramFiles\Windows NT\Accessories",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    )
    foreach ($o in $orte) {
        if (-not $o) { continue }
        $k = Join-Path $o $Name
        if (Test-Path $k) { return $k }
    }
    return $null
}

# Versionierte WindowsApps-Pfade Update-fest machen:
# ...\WindowsApps\Microsoft.DesktopAppInstaller_1.2_x64__hash\x.exe
#   -> ...\WindowsApps\Microsoft.DesktopAppInstaller_*\x.exe
function ConvertTo-RobusterPfad {
    param([string]$Pfad)
    if ($Pfad -match '(?i)\\WindowsApps\\([^\\]+)\\') {
        $paket  = $Matches[1]
        $basis  = ($paket -split '_')[0]
        return ($Pfad -replace [regex]::Escape("\WindowsApps\$paket\"), "\WindowsApps\${basis}_*\")
    }
    return $Pfad
}

$log = Join-Path $env:USERPROFILE ("Lockdown-SRP-Sperrliste-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null

$SaferBasis   = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers"
$DisallowProb = Join-Path $SaferBasis "0\Paths"
$MeineMarke   = "Blockiert vom Lockdown-Skript 43-SRP"

try {
    if ($Entfernen) {
        Write-Schritt "SRP-Sperren entfernen"
        if (Test-Path $DisallowProb) {
            $entfernt = 0
            Get-ChildItem $DisallowProb -ErrorAction SilentlyContinue | ForEach-Object {
                $p = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
                if ($p.Description -eq $MeineMarke) {
                    Remove-Item -Path $_.PSPath -Recurse -Force
                    Write-Ok "Regel entfernt: $($p.ItemData)"
                    $entfernt++
                }
            }
            if ($entfernt -eq 0) { Write-Info "Keine passenden Regeln gefunden." }
        } else { Write-Info "Kein SRP-Regelpfad vorhanden, nichts zu entfernen." }
        & gpupdate /force | Out-Null
        Write-Ok "Fertig. Sperren geloest. Protokoll: $log"
        return
    }

    Write-Schritt "SRP-Sperrliste setzen"

    Set-RegWert $SaferBasis "DefaultLevel"        "DWord" 262144  # Unrestricted (Standard: erlaubt)
    Set-RegWert $SaferBasis "TransparentEnabled"  "DWord" 1
    Set-RegWert $SaferBasis "PolicyScope"         "DWord" 1       # Admins ausgenommen
    Set-RegWert $SaferBasis "authenticodeenabled" "DWord" 0
    $exeTypen = @("ADE","ADP","BAS","BAT","CHM","CMD","COM","CPL","CRT","EXE","HLP","HTA",
                  "INF","INS","ISP","LNK","MDB","MDE","MSC","MSI","MSP","MST","OCX","PCD",
                  "PIF","REG","SCR","SHS","URL","VB","WSC")
    Set-RegWert $SaferBasis "ExecutableTypes" "MultiString" $exeTypen

    if (-not (Test-Path $DisallowProb)) { New-Item -Path $DisallowProb -Force | Out-Null }

    # Eigene Regeln zuerst entfernen (idempotent)
    Get-ChildItem $DisallowProb -ErrorAction SilentlyContinue | ForEach-Object {
        $p = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
        if ($p.Description -eq $MeineMarke) { Remove-Item -Path $_.PSPath -Recurse -Force }
    }

    # Treffer pro Name sammeln (ein Name kann mehrfach vorkommen)
    $gefunden = @{}
    foreach ($d in $Sperrliste) { $gefunden[$d.ToLower()] = New-Object System.Collections.Generic.List[string] }

    # Phase 1: schnelle Aufloesung (uebersprungen bei -Tiefenscan, damit alle Orte gefunden werden)
    if (-not $Tiefenscan) {
        foreach ($d in $Sperrliste) {
            $p = Resolve-Schnell -Name $d
            if ($p) { $gefunden[$d.ToLower()].Add($p) }
        }
    }

    # Phase 2: Tiefenscan ueber alle Laufwerke fuer noch offene Namen
    $offen = $Sperrliste | Where-Object { $gefunden[$_.ToLower()].Count -eq 0 }
    if (-not $SchnellNur -and ($offen.Count -gt 0 -or $Tiefenscan)) {
        $zuSuchen = if ($Tiefenscan) { $Sperrliste } else { $offen }
        $namensSet = @{}
        foreach ($n in $zuSuchen) { $namensSet[$n.ToLower()] = $true }

        $laufwerke = (Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3").DeviceID | ForEach-Object { "$_\" }
        Write-Info "Tiefenscan ueber: $($laufwerke -join ', ') - das kann einige Minuten dauern..."
        foreach ($root in $laufwerke) {
            Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue |
                Where-Object { $namensSet.ContainsKey($_.Name.ToLower()) } |
                ForEach-Object { $gefunden[$_.Name.ToLower()].Add($_.FullName) }
        }
    }

    # Regeln anlegen: je Name je gefundenem (verallgemeinertem, eindeutigem) Pfad eine Regel
    $gesperrt = 0; $nichtGef = @()
    foreach ($d in $Sperrliste) {
        $pfade = $gefunden[$d.ToLower()] | ForEach-Object { ConvertTo-RobusterPfad $_ } |
                 Sort-Object -Unique
        if (-not $pfade -or $pfade.Count -eq 0) { $nichtGef += $d; continue }

        foreach ($vollerPfad in $pfade) {
            $guid      = "{" + [Guid]::NewGuid().ToString() + "}"
            $regelPfad = Join-Path $DisallowProb $guid
            New-Item -Path $regelPfad -Force | Out-Null
            New-ItemProperty -Path $regelPfad -Name "ItemData"     -PropertyType ExpandString -Value $vollerPfad -Force | Out-Null
            New-ItemProperty -Path $regelPfad -Name "SaferFlags"   -PropertyType DWord        -Value 0           -Force | Out-Null
            New-ItemProperty -Path $regelPfad -Name "Description"  -PropertyType String       -Value $MeineMarke -Force | Out-Null
            New-ItemProperty -Path $regelPfad -Name "LastModified" -PropertyType QWord        -Value ([DateTime]::Now.ToFileTime()) -Force | Out-Null
            Write-Ok "$d  ->  $vollerPfad"
            $gesperrt++
        }
    }

    Write-Info "Aktualisiere Richtlinien..."
    & gpupdate /force | Out-Null

    Write-Warn "Sperre gilt NUR im normalen Nutzerkonto (PolicyScope=1 = Admins frei)."
    Write-Warn "Als Verwalter testen zeigt keine Wirkung. Im Alltags-Konto nach Neuanmelden pruefen."
    if ($nichtGef.Count -gt 0) {
        Write-Warn "Nirgends auf dem Geraet gefunden: $($nichtGef -join ', ')"
        Write-Info "Davon sind Store-Apps (photos.exe/maps.exe) per SRP ohnehin nicht blockierbar -> AppLocker/Remove-AppxPackage."
    }
    Write-Ok "Fertig. $gesperrt Regel(n) aktiv. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
