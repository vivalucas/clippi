# Download ffmpeg for Windows

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_DIR = Split-Path -Parent $SCRIPT_DIR
$FFMPEG_DIR = Join-Path $PROJECT_DIR "ffmpeg"

$TARGET_DIR = Join-Path $FFMPEG_DIR "windows-x64"
New-Item -ItemType Directory -Force -Path $TARGET_DIR | Out-Null

Write-Host "Downloading ffmpeg for windows-x64..."

# Download the rolling latest build from BtbN/FFmpeg-Builds. Autobuild tags are
# periodically removed, so pinning one of those tags eventually produces a 404.
$FFMPEG_RELEASE = "latest"
$FFMPEG_ARCHIVE = "ffmpeg-master-latest-win64-gpl.zip"
$FFMPEG_URL = "https://github.com/BtbN/FFmpeg-Builds/releases/download/$FFMPEG_RELEASE/$FFMPEG_ARCHIVE"
$CHECKSUMS_URL = "https://github.com/BtbN/FFmpeg-Builds/releases/download/$FFMPEG_RELEASE/checksums.sha256"
$ZIP_PATH = Join-Path $env:TEMP "ffmpeg.zip"
$CHECKSUMS_PATH = Join-Path $env:TEMP "ffmpeg-checksums.sha256"

Write-Host "Downloading ffmpeg..."
Invoke-WebRequest -Uri $CHECKSUMS_URL -OutFile $CHECKSUMS_PATH
Invoke-WebRequest -Uri $FFMPEG_URL -OutFile $ZIP_PATH

$checksumLine = Get-Content $CHECKSUMS_PATH | Where-Object { $_ -match "\s\*?$([regex]::Escape($FFMPEG_ARCHIVE))$" } | Select-Object -First 1
if (-not $checksumLine) {
    throw "No checksum found for $FFMPEG_ARCHIVE"
}
$FFMPEG_SHA256 = ($checksumLine -split '\s+')[0].ToLowerInvariant()
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
Remove-Item -Path $CHECKSUMS_PATH -Force -ErrorAction SilentlyContinue
Remove-Item -Path $extractedDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "ffmpeg downloaded to $TARGET_DIR"
Get-ChildItem $TARGET_DIR
