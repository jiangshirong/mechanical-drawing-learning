param([string]$GodotPath = "")
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$appRoot = Join-Path $repoRoot "机械制图学习"
$runtimeRoot = Join-Path $appRoot "runtime"
$fontTarget = Join-Path $appRoot "assets/fonts/msyh.ttc"
New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
if (-not (Test-Path -LiteralPath $fontTarget)) {
    $fontSource = Join-Path $env:WINDIR "Fonts/msyh.ttc"
    if (-not (Test-Path -LiteralPath $fontSource)) {
        throw "Microsoft YaHei was not found on this Windows installation. Provide a locally licensed font at assets/fonts/msyh.ttc before running."
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $fontTarget) | Out-Null
    Copy-Item -LiteralPath $fontSource -Destination $fontTarget
}
$engineTarget = Join-Path $runtimeRoot "godot.exe"
if ($GodotPath) {
    $engineSource = (Resolve-Path -LiteralPath $GodotPath).Path
    if ($engineSource -ne $engineTarget) { Copy-Item -LiteralPath $engineSource -Destination $engineTarget }
} elseif (-not (Test-Path -LiteralPath $engineTarget)) {
    $engineCommand = Get-Command godot.exe -ErrorAction SilentlyContinue
    if ($engineCommand) { Copy-Item -LiteralPath $engineCommand.Source -Destination $engineTarget }
    else { throw "Install Godot 4.7.x, then rerun with -GodotPath pointing to its executable. See README.md." }
}
$versionFile = Join-Path $runtimeRoot "engine-version.txt"
$versionError = Join-Path $runtimeRoot "engine-version-error.txt"
$versionProcess = Start-Process -FilePath $engineTarget -ArgumentList "--version" -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $versionFile -RedirectStandardError $versionError
if ($versionProcess.ExitCode -ne 0) { throw "Godot --version failed. See runtime/engine-version-error.txt." }
$versionOutput = (Get-Content -LiteralPath $versionFile -Raw).Trim()
Write-Host "Godot: $versionOutput"
Write-Host "Ready. Open 机械制图学习/project.godot, or run 机械制图学习/开始学习.cmd."
