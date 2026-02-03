#!/bin/bash

# Docan AUR Package Build Script
# This script orchestrates the complete package creation process

set -e

echo "Building Docan AUR package..."

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Define paths
PROJECT_ROOT="/home/www/DEV-trunk/docan"
BUILD_DIR="$PROJECT_ROOT/build/linux/x64/release/bundle"
ICON_DIR="$PROJECT_ROOT/linux/data/icons/hicolor"
DESKTOP_FILE="$PROJECT_ROOT/linux/docan.desktop"

# Check if build exists
if [ ! -d "$BUILD_DIR" ]; then
    echo "Error: Build directory not found at $BUILD_DIR"
    echo "Please run 'flutter build linux --release' in $PROJECT_ROOT first."
    exit 1
fi

# Copy binary
echo "Copying binary..."
cp "$BUILD_DIR/docan" .

# Copy desktop file
echo "Copying desktop file..."
cp "$DESKTOP_FILE" .

# Create Flutter assets archive
echo "Creating Flutter assets archive..."
if [ -d "$BUILD_DIR/data" ]; then
    tar -czf flutter_assets.tar.gz -C "$BUILD_DIR" data/
else
    echo "Warning: No data directory found in build"
fi

# Create libraries archive
echo "Creating libraries archive..."
if [ -d "$BUILD_DIR/lib" ]; then
    tar -czf lib.tar.gz -C "$BUILD_DIR" lib/
else
    echo "Warning: No lib directory found in build"
fi

# Create plugins archive (optional)
echo "Creating plugins archive..."
if [ -d "$BUILD_DIR/plugins" ]; then
    tar -czf plugins.tar.gz -C "$BUILD_DIR" plugins/
    echo "Plugins archive created."
else
    echo "No plugins directory found - skipping plugins archive."
fi

# Create icons archive
echo "Creating icons archive..."
mkdir -p temp_icons
for size in 32 48 64 96 128 192 256 512; do
    if [ -f "$ICON_DIR/${size}x${size}/apps/docan.png" ]; then
        mkdir -p "temp_icons/${size}x${size}/apps"
        cp "$ICON_DIR/${size}x${size}/apps/docan.png" "temp_icons/${size}x${size}/apps/"
    fi
done
tar -czf icons.tar.gz -C temp_icons .
rm -rf temp_icons

echo "Package files prepared successfully!"
echo ""
echo "To build and install the AUR package:"
echo "  makepkg -si"
echo ""
echo "Or with yay:"
echo "  yay -S ."
echo ""
echo "Or with trizen:"
echo "  trizen -S ."
