param([ValidateSet("win-x64", "win-arm64")][string]$Runtime = "win-x64")
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path $PSScriptRoot -Parent
$output = Join-Path $projectRoot "dist/Today-$Runtime"
Push-Location (Join-Path $projectRoot "Windows")
try {
    dotnet publish Today.Windows/Today.Windows.csproj -c Release -r $Runtime --self-contained true `
        -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:PublishTrimmed=false -o $output
    if ($LASTEXITCODE -ne 0) { throw "Windows build failed." }
    Write-Output "Built: $output/Today.exe"
} finally { Pop-Location }
