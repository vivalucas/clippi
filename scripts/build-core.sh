#!/bin/bash
# Build Rust core library for macOS/Linux

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CORE_DIR="$PROJECT_DIR/core"

echo "Building Rust core library..."

cd "$CORE_DIR"
cargo build --release

# Copy the built library to the appropriate location
if [[ "$(uname -s)" == "Darwin" ]]; then
    mkdir -p "$PROJECT_DIR/macos/Clippi/Libraries"
    cp "$CORE_DIR/target/release/libclippi_core.dylib" "$PROJECT_DIR/macos/Clippi/Libraries/"
    echo "Copied libclippi_core.dylib to macos/Clippi/Libraries/"
else
    mkdir -p "$PROJECT_DIR/lib/linux"
    cp "$CORE_DIR/target/release/libclippi_core.so" "$PROJECT_DIR/lib/linux/"
    echo "Copied libclippi_core.so to lib/linux/"
fi

echo "Build complete!"
