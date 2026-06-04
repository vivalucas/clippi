# Download ffmpeg for Windows

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_DIR = Split-Path -Parent $SCRIPT_DIR
$FFMPEG_DIR = Join-Path $PROJECT_DIR "ffmpeg"

$TARGET_DIR = Join-Path $FFMPEG_DIR "windows-x64"
New-Item -ItemType Directory -Force -Path $TARGET_DIR | Out-Null

Write-Host "Downloading ffmpeg for windows-x64..."

# Download from BtbN/FFmpeg-Builds
$FFMPEG_RELEASE = "autobuild-2026-06-03-14-37"
$FFMPEG_ARCHIVE = "ffmpeg-n7.1.4-9-gc06af95f12-win64-gpl-7.1.zip"
$FFMPEG_SHA256 = "305f5ac85ab794431fd32c724a30e2a8638b54fee6d2d983233685d937ccb9c7"
$FFMPEG_URL = "https://github.com/BtbN/FFmpeg-Builds/releases/download/$FFMPEG_RELEASE/$FFMPEG_ARCHIVE"
$ZIP_PATH = Join-Path $env:TEMP "ffmpeg.zip"

Write-Host "Downloading ffmpeg..."
Invoke-WebRequest -Uri $FFMPEG_URL -OutFile $ZIP_PATH

$actualHash = (Get-FileHash -Path $ZIP_PATH -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $FFMPEG_SHA256) {
    throw "ffmpeg checksum mismatch. Expected $FFMPEG_SHA256, got $actualHash"
}

Write-Host "Extracting..."
Expand-Archive -Path $ZIP_PATH -DestinationPath $env:TEMP -Force

# Move bin contents to target dir
$extractedDir = Join-Path $env:TEMP ($FFMPEG_ARCHIVE -replace "\.zip$", "")
$binDir = Join-Path $extractedDir "bin"

if (Test-Path $binDir) {
    Copy-Item -Path "$binDir\*" -Destination $TARGET_DIR -Force
}

# Cleanup
Remove-Item -Path $ZIP_PATH -Force -ErrorAction SilentlyContinue
Remove-Item -Path $extractedDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "ffmpeg downloaded to $TARGET_DIR"
Get-ChildItem $TARGET_DIR
