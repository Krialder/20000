#Requires -RunAsAdministrator
<#  44-SRP-Aufraeumen.ps1
    Eigenstaendiges Aufraeum-Skript fuer 43-Programme-sperren-SRP.ps1.

    Ein frueherer Lauf hat SRP-Regeln mit NUR dem Dateinamen angelegt
    (z.B. ItemData = "wordpad.exe"). Solche Regeln greifen in SRP nicht
    (SRP braucht den vollen Pfad) und sind toter Ballast in der Registry.
    Dieses Skript findet und entfernt genau diese kaputten Regeln.

    Erkannt wird eine kaputte Regel daran, dass ihr ItemData KEINEN
    vollen Pfad enthaelt (kein "\" und kein Laufwerksbuchstabe). Korrekte
    Regeln mit vollem Pfad (z.B. "C:\...\wordpad.exe") bleiben unberuehrt.

    Standardmaessig werden nur Regeln aus diesem Projekt angefasst
    (Description = "Blockiert vom Lockdown-Skript 43-SRP"). Mit -Alle werden
    auch fremde namensbasierte SRP-Regeln entfernt (vorsichtig nutzen).

    Beispiele:
      .\44-SRP-Aufraeumen.ps1                 # kaputte Projekt-Regeln entfernen
      .\44-SRP-Aufraeumen.ps1 -NurAnzeigen    # nur auflisten, nichts loeschen
      .\44-SRP-Aufraeumen.ps1 -Alle           # auch fremde Namensregeln

    Hinweis Ausfuehrung: Laeuft die PS1 nicht ("auf diesem System deaktiviert"),
    vorher in derselben Admin-PowerShell einmalig:
      Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>
[CmdletBinding()]
param(
    [switch]$NurAnzeigen,
    [switch]$Alle
)
$ErrorActionPreference = 'Stop'

function Write-Schritt { param([string]$Text) Write-Host "[ $Text ]" -ForegroundColor Cyan }
function Write-Ok      { param([string]$Text) Write-Host "  OK   $Text" -ForegroundColor Green }
function Write-Warn    { param([string]$Text) Write-Host "  WARN $Text" -ForegroundColor Yellow }
function Write-Info    { param([string]$Text) Write-Host "       $Text" -ForegroundColor Gray }

# Ist das ein vollstaendiger Pfad? Vollstaendig = enthaelt "\" (z.B. C:\...\x.exe
# oder eine Umgebungsvariable wie %ProgramFiles%\...). Ein blosser "wordpad.exe"
# ist NICHT vollstaendig und damit eine kaputte SRP-Regel.
function Test-VollerPfad { param([string]$Wert) return ($Wert -match '\\') }

$log = Join-Path $env:USERPROFILE ("Lockdown-SRP-Aufraeumen-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null

$DisallowProb = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers\0\Paths"
$MeineMarke   = "Blockiert vom Lockdown-Skript 43-SRP"

try {
    Write-Schritt "SRP-Regeln pruefen"

    if (-not (Test-Path $DisallowProb)) {
        Write-Info "Kein SRP-Regelpfad vorhanden. Nichts zu tun."
        return
    }

    $entfernt = 0; $behalten = 0
    Get-ChildItem $DisallowProb -ErrorAction SilentlyContinue | ForEach-Object {
        $props = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
        $item  = $props.ItemData
        $desc  = $props.Description
        if (-not $item) { return }

        $istMeine  = ($desc -eq $MeineMarke)
        $istKaputt = -not (Test-VollerPfad $item)

        # Im Standard nur eigene, kaputte Regeln. Mit -Alle jede kaputte Namensregel.
        $loeschen = $istKaputt -and ($istMeine -or $Alle)

        if ($loeschen) {
            if ($NurAnzeigen) {
                Write-Warn "WUERDE entfernen: '$item'$(if(-not $istMeine){' (fremde Regel)'})"
            } else {
                Remove-Item -Path $_.PSPath -Recurse -Force
                Write-Ok "Entfernt (kaputter Namens-Eintrag): '$item'"
            }
            $entfernt++
        } else {
            if (Test-VollerPfad $item) { Write-Info "Behalten (voller Pfad): '$item'" }
            else { Write-Info "Behalten (fremde Namensregel, nutze -Alle zum Entfernen): '$item'" }
            $behalten++
        }
    }

    if ($NurAnzeigen) {
        Write-Info "Nur-Anzeigen: $entfernt kaputte Regel(n) gefunden, $behalten behalten. Nichts geloescht."
    } else {
        if ($entfernt -gt 0) {
            Write-Info "Aktualisiere Richtlinien..."
            & gpupdate /force | Out-Null
        }
        Write-Ok "Fertig. $entfernt kaputte Regel(n) entfernt, $behalten behalten. Protokoll: $log"
    }
} finally { Stop-Transcript | Out-Null }
