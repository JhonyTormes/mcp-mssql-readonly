param(
    [string]$Runtime = "win-x64",
    [string]$OutputDir = "build"
)

$project = "src\McpSqlServer\McpSqlServer.csproj"

if (-not (Test-Path $project)) {
    Write-Error "Project file not found: $project"
    exit 1
}

Write-Host "Publishing $project as self-contained ($Runtime)..." -ForegroundColor Cyan

dotnet publish $project `
    -c Release `
    --self-contained true `
    -r $Runtime `
    -o $OutputDir `
    -p:PublishSingleFile=true `
    -p:PublishTrimmed=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:DebugSymbols=false `
    -p:DebugType=none

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nPublished to $OutputDir successfully!" -ForegroundColor Green

    $exe = Join-Path $OutputDir "McpSqlServer.exe"
    if (Test-Path $exe) {
        $size = (Get-Item $exe).Length / 1MB
        Write-Host "Binary size: $([math]::Round($size, 1)) MB" -ForegroundColor Yellow
    }
} else {
    Write-Error "Publish failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
