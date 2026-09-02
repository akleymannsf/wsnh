#Requires -Version 5.1
<#
    Builds WSNH into a single, self-contained WSNH.exe -- no .NET install
    required on the machine that runs it, no separate signing step needed
    (unlike the Mac build, Windows doesn't require a stable local
    certificate identity for permissions to survive rebuilds).
#>

$ErrorActionPreference = "Stop"

Write-Host "==> Publishing WSNH (self-contained, single file)..."
dotnet publish WSNH.csproj `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:EnableCompressionInSingleFile=true

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed -- see the dotnet output above."
    exit 1
}

$publishDir = "bin\Release\net8.0-windows\win-x64\publish"
Write-Host ""
Write-Host "Done. WSNH.exe is in $publishDir"
Write-Host "Run .\package.ps1 to zip it up for sharing."
