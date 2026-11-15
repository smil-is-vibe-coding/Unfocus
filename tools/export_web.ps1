# Builds the browser (WebAssembly) version into build/web/ and optionally
# serves it locally.
#
#   powershell -ExecutionPolicy Bypass -File tools/export_web.ps1           # build
#   powershell -ExecutionPolicy Bypass -File tools/export_web.ps1 -Serve    # build + open http://localhost:8000
#
# Needs the Godot 4.7.2 export templates installed
# (Editor > Manage Export Templates > Download, or the official .tpz).

param(
    [string]$Godot = "$env:USERPROFILE\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
    [switch]$Serve
)

$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot
$out = Join-Path $project "build\web"

if (-not (Test-Path $Godot)) {
    Write-Error "Godot not found at '$Godot'. Pass -Godot <path to Godot_v4.7.2-stable_win64_console.exe>."
}

New-Item -ItemType Directory -Force $out | Out-Null
Write-Host "Exporting Web build to $out ..."
& $Godot --headless --path $project --export-release "Web" (Join-Path $out "index.html")
if ($LASTEXITCODE -ne 0) { Write-Error "Export failed (exit $LASTEXITCODE)." }

Write-Host ""
Write-Host "Done. Static files to host:" -ForegroundColor Cyan
Get-ChildItem $out | Format-Table Name, @{N="Size (MB)"; E={[math]::Round($_.Length / 1MB, 2)}} -AutoSize

if ($Serve) {
    Write-Host "Serving on http://localhost:8000  (Ctrl+C to stop)" -ForegroundColor Cyan
    Start-Process "http://localhost:8000"
    python -m http.server 8000 --directory $out
}
