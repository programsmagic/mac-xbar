#!/bin/bash
set -e

echo ""
echo "  mac-xbar build script..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Resolving dependencies..."
swift package resolve

echo "==> Building..."
swift build -c release

echo "==> Running tests..."
swift test

echo ""
echo "  Build complete!"
echo "  App: .build/release/mac-xbar"