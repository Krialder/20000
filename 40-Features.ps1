#Requires -RunAsAdministrator
<#  40-Features.ps1
    Deaktiviert alternative Ausfuehrungsumgebungen: WSL, VM-Plattform, Hyper-V,
    Windows-Sandbox, Hypervisor-Plattform und PowerShell 2.0.
    Danach NEUSTART noetig.
#>
[CmdletBinding()] param()
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_Common.ps1"
$log = Join-Path $env:USERPROFILE ("Lockdown-Features-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $log -Append | Out-Null
try {
    Write-Schritt "Alternative Ausfuehrungsumgebungen deaktivieren"
    $features = @(
        'Microsoft-Hyper-V-All',
        'Containers-DisposableClientVM',     # Windows-Sandbox
        'Microsoft-Windows-Subsystem-Linux',
        'VirtualMachinePlatform',
        'HypervisorPlatform',
        'MicrosoftWindowsPowerShellV2Root',
        'MicrosoftWindowsPowerShellV2'
    )
    foreach ($f in $features) {
        $state = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue
        if (-not $state) { Write-Info "$f nicht vorhanden, uebersprungen"; continue }
        if ($state.State -eq 'Enabled') {
            Disable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart | Out-Null
            Write-Ok "$f deaktiviert"
        } else { Write-Info "$f ist bereits deaktiviert" }
    }
    Write-Warn "NEUSTART noetig, damit die Deaktivierungen wirksam werden."
    Write-Ok "Features abgeschlossen. Protokoll: $log"
} finally { Stop-Transcript | Out-Null }
