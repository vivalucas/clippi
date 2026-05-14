# Build Rust core library for Windows

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_DIR = Split-Path -Parent $SCRIPT_DIR
$CORE_DIR = Join-Path $PROJECT_DIR "core"

Write-Host "Building Rust core library..."

Set-Location $CORE_DIR
cargo build --release

# Copy the built library to the Windows project
$TARGET_DIR = Join-Path $PROJECT_DIR "windows\Clippi\Libraries"
New-Item -ItemType Directory -Force -Path $TARGET_DIR | Out-Null

Copy-Item -Path "$CORE_DIR\target\release\clippi_core.dll" -Destination $TARGET_DIR -Force
Write-Host "Copied clippi_core.dll to windows\Clippi\Libraries\"

Write-Host "Build complete!"
