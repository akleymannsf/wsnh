#Requires -Version 5.1
<#
    Zips the published WSNH.exe up for sharing with colleagues. Run
    .\build.ps1 first.
#>

$ErrorActionPreference = "Stop"

$publishDir = "bin\Release\net8.0-windows\win-x64\publish"
$exePath = Join-Path $publishDir "WSNH.exe"

if (-not (Test-Path $exePath)) {
    Write-Error "WSNH.exe not found at $exePath -- run .\build.ps1 first."
    exit 1
}

$zipPath = "WSNH-Windows.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath }

Write-Host "==> Zipping WSNH.exe for distribution..."
Compress-Archive -Path $exePath -DestinationPath $zipPath

Write-Host ""
Write-Host "Done. $zipPath is ready in this folder."
Write-Host "Share it along with README.md -- colleagues just need to unzip and"
Write-Host "run WSNH.exe (no .NET install required, it's self-contained)."
