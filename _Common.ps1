<#
================================================================================
 _Common.ps1
 Gemeinsame Hilfsfunktionen fuer alle Lockdown-Skripte. Wird von jedem Skript
 ueber  . "$PSScriptRoot\_Common.ps1"  eingebunden. Nicht direkt ausfuehren.
================================================================================
#>

function Write-Schritt { param([string]$Text) Write-Host "[ $Text ]" -ForegroundColor Cyan }
function Write-Ok      { param([string]$Text) Write-Host "  OK   $Text" -ForegroundColor Green }
function Write-Warn    { param([string]$Text) Write-Host "  WARN $Text" -ForegroundColor Yellow }
function Write-Info    { param([string]$Text) Write-Host "       $Text" -ForegroundColor Gray }

# Sprachunabhaengig ueber die SID: Administratoren = S-1-5-32-544, Benutzer = S-1-5-32-545
function Get-GruppeNachSid { param([string]$Sid) Get-LocalGroup | Where-Object { $_.SID.Value -eq $Sid } }

function Test-IstPro {
    $os = (Get-CimInstance Win32_OperatingSystem).Caption
    if ($os -notmatch 'Pro|Enterprise|Education') {
        Write-Warn "Edition: $os. Dieses Paket ist fuer Pro gedacht. Auf Home fehlen BitLocker und die WDAC-Cmdlets."
        return $false
    }
    Write-Ok "Edition: $os"; return $true
}

function Set-RegWert {
    param([string]$Pfad,[string]$Name,[string]$Typ,$Wert)
    if (-not (Test-Path $Pfad)) { New-Item -Path $Pfad -Force | Out-Null }
    New-ItemProperty -Path $Pfad -Name $Name -PropertyType $Typ -Value $Wert -Force | Out-Null
    Write-Ok "$Pfad\$Name = $Wert"
}

# Setzt die Gruppenrichtlinie, damit BitLocker ohne kompatibles TPM moeglich ist.
function Set-FveOhneTpm {
    param([switch]$Passwort,[switch]$UsbKey)
    $fve = "HKLM:\SOFTWARE\Policies\Microsoft\FVE"
    Set-RegWert $fve "UseAdvancedStartup" "DWord" 1
    Set-RegWert $fve "EnableBDEWithNoTPM" "DWord" 1
    Set-RegWert $fve "UseTPM"       "DWord" 2
    Set-RegWert $fve "UseTPMPIN"    "DWord" 2
    Set-RegWert $fve "UseTPMKey"    "DWord" 2
    Set-RegWert $fve "UseTPMKeyPIN" "DWord" 2
    if ($Passwort) {
        Set-RegWert $fve "OSPassphrase"           "DWord" 1
        Set-RegWert $fve "OSPassphraseComplexity" "DWord" 0
        Set-RegWert $fve "OSPassphraseLength"     "DWord" 8
    }
    Write-Ok "FVE-Richtlinie fuer BitLocker ohne TPM gesetzt"
}

# Baut und rollt die WDAC-Richtlinie aus. Wird von 60- und 62- genutzt.
function Build-WdacPolicy {
    param([switch]$Audit,[switch]$EntwicklungsumgebungErlaubt,[string]$WdacOrdner='C:\WDAC')

    New-Item -ItemType Directory -Force -Path $WdacOrdner | Out-Null
    $base   = Join-Path $WdacOrdner 'Base.xml'
    $merged = Join-Path $WdacOrdner 'Merged.xml'
    $bin    = Join-Path $WdacOrdner 'SiPolicy.p7b'
    $block  = Join-Path $WdacOrdner 'BlockRules.xml'
    $driver = Join-Path $WdacOrdner 'DriverBlockRules.xml'

    # 1) Allowlist aus den geschuetzten Pfaden scannen (Publisher mit Hash-Fallback)
    if (-not (Test-Path $base)) {
        Write-Info "Scanne Program Files und Windows. Das dauert einige Minuten."
        if ($EntwicklungsumgebungErlaubt) { Write-Warn "Option B: Entwicklungswerkzeuge werden mitgescannt und damit erlaubt." }
        else { Write-Info "Option A: nur installierte Arbeitsprogramme werden erlaubt." }
        $scanPfade = @("$env:ProgramFiles","${env:ProgramFiles(x86)}","$env:SystemRoot")
        $teile = @(); $i = 0
        foreach ($p in $scanPfade) {
            if (-not (Test-Path $p)) { continue }
            $teil = Join-Path $WdacOrdner ("Scan{0}.xml" -f $i)
            New-CIPolicy -FilePath $teil -Level FilePublisher -Fallback Hash -UserPEs -ScanPath $p -NoShadowCopy 3>$null
            $teile += $teil; $i++
        }
        if ($teile.Count -gt 1) { Merge-CIPolicy -PolicyPaths $teile -OutputFilePath $base | Out-Null }
        else { Copy-Item $teile[0] $base -Force }
        Write-Ok "Allowlist erstellt: $base"
    } else { Write-Info "Vorhandene Allowlist wird genutzt: $base" }

    # 2) Microsofts Sperrlisten einmischen, falls vorhanden
    $mischen = @($base)
    if (Test-Path $block)  { $mischen += $block;  Write-Ok "BlockRules.xml gefunden" }
    else { Write-Warn "BlockRules.xml fehlt in $WdacOrdner. Von Microsoft Learn 'Application Control for Business Microsoft recommended block rules' holen." }
    if (Test-Path $driver) { $mischen += $driver; Write-Ok "DriverBlockRules.xml gefunden" }
    else { Write-Warn "DriverBlockRules.xml fehlt in $WdacOrdner. Von Microsoft Learn 'Microsoft recommended driver block rules' holen." }
    Merge-CIPolicy -PolicyPaths $mischen -OutputFilePath $merged | Out-Null
    Set-CIPolicyIdInfo -FilePath $merged -PolicyName "Lockdown-Allowlist" | Out-Null

    # 3) Deny-Regeln auf die fuer Standardnutzer beschreibbaren Pfade unter C:\Windows
    $denyPfade = @(
        'C:\Windows\Temp\*','C:\Windows\Tasks\*','C:\Windows\Tracing\*',
        'C:\Windows\System32\spool\drivers\color\*','C:\Windows\System32\FxsTmp\*','C:\Windows\System32\Tasks\*'
    )
    foreach ($d in $denyPfade) {
        try {
            $r = New-CIPolicyRule -FilePathRule $d -Deny
            Merge-CIPolicy -PolicyPaths $merged -Rules $r -OutputFilePath $merged | Out-Null
            Write-Ok "Deny-Regel: $d"
        } catch { Write-Warn "Deny-Regel '$d' nicht per Cmdlet moeglich. Im WDAC-Wizard als Pfadregel mit Aktion Deny ergaenzen." }
    }

    # 4) Regeloptionen: 0 UMCI, 6 unsignierte Richtlinie, 19 dynamische Codepruefung,
    #    11 ENTFERNT = Skript-Erzwingung aktiv (Constrained Language Mode),
    #    14 ENTFERNT = Reputationsoption ISG aus, 3 = Audit (nur in der Audit-Variante)
    Set-RuleOption -FilePath $merged -Option 0
    Set-RuleOption -FilePath $merged -Option 6
    Set-RuleOption -FilePath $merged -Option 19
    Set-RuleOption -FilePath $merged -Option 11 -Delete
    Set-RuleOption -FilePath $merged -Option 14 -Delete
    if ($Audit) { Set-RuleOption -FilePath $merged -Option 3;        Write-Ok "Audit-Modus gesetzt (Option 3)" }
    else        { Set-RuleOption -FilePath $merged -Option 3 -Delete; Write-Ok "Erzwingung gesetzt (Audit-Modus entfernt)" }

    # 5) Kompilieren und ausrollen
    ConvertFrom-CIPolicy -XmlFilePath $merged -BinaryFilePath $bin | Out-Null
    $ziel = "$env:SystemRoot\System32\CodeIntegrity\SiPolicy.p7b"
    Copy-Item $bin $ziel -Force
    Write-Ok "Richtlinie ausgerollt nach $ziel"
    Write-Warn "NEUSTART noetig, damit die Richtlinie geladen wird."
}
