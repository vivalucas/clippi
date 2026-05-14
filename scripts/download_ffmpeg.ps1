# Download ffmpeg for Windows

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_DIR = Split-Path -Parent $SCRIPT_DIR
$FFMPEG_DIR = Join-Path $PROJECT_DIR "ffmpeg"

$TARGET_DIR = Join-Path $FFMPEG_DIR "windows-x64"
New-Item -ItemType Directory -Force -Path $TARGET_DIR | Out-Null

Write-Host "Downloading ffmpeg for windows-x64..."

# Download from BtbN/FFmpeg-Builds
$FFMPEG_URL = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
$ZIP_PATH = Join-Path $env:TEMP "ffmpeg.zip"

Write-Host "Downloading ffmpeg..."
Invoke-WebRequest -Uri $FFMPEG_URL -OutFile $ZIP_PATH

Write-Host "Extracting..."
Expand-Archive -Path $ZIP_PATH -DestinationPath $env:TEMP -Force

# Move bin contents to target dir
$extractedDir = Join-Path $env:TEMP "ffmpeg-master-latest-win64-gpl"
$binDir = Join-Path $extractedDir "bin"

if (Test-Path $binDir) {
    Copy-Item -Path "$binDir\*" -Destination $TARGET_DIR -Force
}

# Cleanup
Remove-Item -Path $ZIP_PATH -Force -ErrorAction SilentlyContinue
Remove-Item -Path $extractedDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "ffmpeg downloaded to $TARGET_DIR"
Get-ChildItem $TARGET_DIR
