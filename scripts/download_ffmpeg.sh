#!/bin/bash
# Download ffmpeg for macOS/Linux

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FFMPEG_DIR="$PROJECT_DIR/ffmpeg"

# Detect platform
if [[ "$(uname -s)" == "Darwin" ]]; then
    PLATFORM="macos"
    if [[ "$(uname -m)" == "arm64" ]]; then
        ARCH="arm64"
    else
        ARCH="x64"
    fi
else
    echo "Unsupported platform: $(uname -s)"
    exit 1
fi

TARGET_DIR="$FFMPEG_DIR/$PLATFORM-$ARCH"
mkdir -p "$TARGET_DIR"

echo "Downloading ffmpeg for $PLATFORM-$ARCH..."

# Download from evermeet.cx for macOS
if [[ "$PLATFORM" == "macos" ]]; then
    FFMPEG_URL="https://evermeet.cx/ffmpeg/ffmpeg-7.1.1.zip"
    FFPROBE_URL="https://evermeet.cx/ffmpeg/ffprobe-7.1.1.zip"

    echo "Downloading ffmpeg..."
    curl -L "$FFMPEG_URL" -o /tmp/ffmpeg.zip
    unzip -o /tmp/ffmpeg.zip -d "$TARGET_DIR"

    echo "Downloading ffprobe..."
    curl -L "$FFPROBE_URL" -o /tmp/ffprobe.zip
    unzip -o /tmp/ffprobe.zip -d "$TARGET_DIR"

    rm /tmp/ffmpeg.zip /tmp/ffprobe.zip
fi

echo "ffmpeg downloaded to $TARGET_DIR"
ls -la "$TARGET_DIR"
