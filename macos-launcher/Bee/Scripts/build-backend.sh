#!/bin/bash
# Build backend script for Xcode build phase
#
# This script builds the bee-api Rust backend and copies it to Resources.
# Add this as a "Run Script" build phase in Xcode BEFORE "Compile Sources".
#
# To add in Xcode:
# 1. Select the Bee project in the navigator
# 2. Select the Bee target
# 3. Go to Build Phases tab
# 4. Click + → New Run Script Phase
# 5. Drag it BEFORE "Compile Sources"
# 6. Paste: ${SRCROOT}/Scripts/build-backend.sh
# 7. UNCHECK "Based on dependency analysis" to force rebuild

set -e

# Xcode doesn't inherit shell PATH, so use full path to cargo
CARGO="${HOME}/.cargo/bin/cargo"

if [ ! -x "$CARGO" ]; then
    echo "error: cargo not found at $CARGO"
    echo "Install Rust: https://rustup.rs"
    exit 1
fi

# Go to repo root (two levels up from Bee.xcodeproj)
cd "${SRCROOT}/../.."

# Match Cargo build mode to Xcode configuration
if [ "$CONFIGURATION" = "Release" ]; then
    CARGO_FLAGS="--release"
    CARGO_TARGET_DIR="target/release"
else
    CARGO_FLAGS=""
    CARGO_TARGET_DIR="target/debug"
fi

echo "Building bee-api ($CONFIGURATION mode)..."
"$CARGO" build -p bee-api $CARGO_FLAGS

# Copy binary to Resources folder (preserving permissions)
mkdir -p "${SRCROOT}/Resources"
cp -p "$CARGO_TARGET_DIR/beed" "${SRCROOT}/Resources/"
chmod 755 "${SRCROOT}/Resources/beed"

echo "✓ Backend binary (beed) copied to Resources/"
