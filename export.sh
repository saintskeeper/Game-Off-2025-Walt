#!/bin/bash
# Export script - regenerates pathing data then builds game for all platforms as zip files
# Platforms: web (html5), macOS, Windows, and Linux

set -e  # Exit on error

# Get the script directory and navigate to it
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "DragonRuby Game Export Script"
echo "=========================================="
echo ""

# Step 1: Regenerate pathing data
echo "Step 1: Regenerating pathing data..."
cd tools
if [ -d "venv" ]; then
    source venv/bin/activate
    python generate_pathing_from_layers.py --scale 3
    deactivate
else
    echo "Warning: venv not found, skipping pathing data generation"
fi
cd "$SCRIPT_DIR"
echo "✓ Pathing data regenerated"
echo ""

# Step 2: Navigate to project root (where dragonruby-publish is located)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Step 3: Clean previous builds (optional, but recommended)
if [ -d "builds" ]; then
    echo "Step 2: Cleaning previous builds..."
    rm -rf builds
    echo "✓ Previous builds cleaned"
    echo ""
fi

# Step 4: Build for all platforms
echo "Step 3: Building game for all platforms..."
echo "  - Web (HTML5)"
echo "  - macOS"
echo "  - Windows (AMD64)"
echo "  - Linux (AMD64)"
echo ""

# Run dragonruby-publish with specified platforms
# Note: dragonruby-publish creates zip files in the builds directory
./dragonruby-publish \
    --platforms=html5,macos,windows-amd64,linux-amd64 \
    --package \
    mygame

echo ""
echo "=========================================="
echo "Export Complete!"
echo "=========================================="
echo ""
echo "Build artifacts are located in:"
echo "  $PROJECT_ROOT/builds"
echo ""
echo "Platform builds created:"
echo "  - Web: Look for html5 zip file"
echo "  - macOS: Look for macos zip file"
echo "  - Windows: Look for windows-amd64 zip file"
echo "  - Linux: Look for linux-amd64 zip file"
echo ""
echo "You can now upload these zip files to your distribution platform."
echo ""

