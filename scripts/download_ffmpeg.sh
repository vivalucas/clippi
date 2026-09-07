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

# Download architecture-matched static binaries for macOS.
if [[ "$PLATFORM" == "macos" ]]; then
    if [[ "$ARCH" == "arm64" ]]; then
        FFMPEG_URL="https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffmpeg-darwin-arm64"
        FFPROBE_URL="https://github.com/eugeneware/ffmpeg-static/releases/download/b6.1.1/ffprobe-darwin-arm64"
        FFMPEG_SHA256="a90e3db6a3fd35f6074b013f948b1aa45b31c6375489d39e572bea3f18336584"
        FFPROBE_SHA256="bb2db6f5d8cef919da12fbf592119a987202a8c060a886f3cab091f9cab90b64"

        echo "Downloading ffmpeg..."
        curl --fail --location "$FFMPEG_URL" -o "$TARGET_DIR/ffmpeg"
        echo "$FFMPEG_SHA256  $TARGET_DIR/ffmpeg" | shasum -a 256 -c -

        echo "Downloading ffprobe..."
        curl --fail --location "$FFPROBE_URL" -o "$TARGET_DIR/ffprobe"
        echo "$FFPROBE_SHA256  $TARGET_DIR/ffprobe" | shasum -a 256 -c -
    else
        FFMPEG_URL="https://evermeet.cx/ffmpeg/ffmpeg-7.1.1.zip"
        FFPROBE_URL="https://evermeet.cx/ffmpeg/ffprobe-7.1.1.zip"
        FFMPEG_SHA256="8d7917c1cebd7a29e68c0a0a6cc4ecc3fe05c7fffed958636c7018b319afdda4"
        FFPROBE_SHA256="5a0a77d5e0c689f7b577788e286dd46b2c6120babd14301cce7a79fcfd3f7d28"

        echo "Downloading ffmpeg..."
        curl --fail --location "$FFMPEG_URL" -o /tmp/ffmpeg.zip
        echo "$FFMPEG_SHA256  /tmp/ffmpeg.zip" | shasum -a 256 -c -
        unzip -o /tmp/ffmpeg.zip -d "$TARGET_DIR"

        echo "Downloading ffprobe..."
        curl --fail --location "$FFPROBE_URL" -o /tmp/ffprobe.zip
        echo "$FFPROBE_SHA256  /tmp/ffprobe.zip" | shasum -a 256 -c -
        unzip -o /tmp/ffprobe.zip -d "$TARGET_DIR"

        rm /tmp/ffmpeg.zip /tmp/ffprobe.zip
    fi

    chmod +x "$TARGET_DIR/ffmpeg" "$TARGET_DIR/ffprobe"
fi

echo "ffmpeg downloaded to $TARGET_DIR"
ls -la "$TARGET_DIR"
