# Register or unregister the T-Time Text Service (requires Administrator).
# Usage:
#   pwsh -File windows/register.ps1              # register build/windows/TTimeTSF.dll
#   pwsh -File windows/register.ps1 -Unregister
#   pwsh -File windows/register.ps1 -Dll path\to\TTimeTSF.dll
param(
    [string]$Dll = "",
    [switch]$Unregister
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
if (-not $Dll) {
    $Dll = Join-Path $root "build\windows\TTimeTSF.dll"
}
if (-not (Test-Path $Dll)) {
    Write-Error "DLL not found: $Dll`nBuild first with: pwsh scripts/build-windows-tsf.ps1"
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Run this script from an elevated PowerShell (Run as administrator)."
}

$regsvr = Join-Path $env:SystemRoot "System32\regsvr32.exe"
if ($Unregister) {
    & $regsvr /s /u $Dll
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "Unregistered $Dll"
} else {
    & $regsvr /s $Dll
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "Registered $Dll"
    Write-Host ""
    Write-Host "Next: Settings → Time & Language → Language & region → English (United States)"
    Write-Host "  → Language options → Keyboards → Add a keyboard → T-Time"
    Write-Host "Then pick T-Time from the taskbar input menu and type in Notepad."
}
