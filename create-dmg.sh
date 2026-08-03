#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="mac-xbar"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
VERSION="1.1.0"

echo ""
echo "  mac-xbar DMG build..."
echo ""

# Compile binary if it doesn't exist
if [ ! -f "${APP_NAME}" ]; then
    echo "==> Compiling binary..."
    SWIFT_FLAGS="-target arm64-apple-macosx14.0 -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
    SWIFT_FLAGS="$SWIFT_FLAGS -I /Library/Developer/CommandLineTools/Library/Developer/Frameworks"
    SWIFT_FLAGS="$SWIFT_FLAGS -L /Library/Developer/CommandLineTools/Library/Developer/Frameworks"
    SRC_FILES=$(find Sources -name "*.swift" | sort)
    swiftc $SWIFT_FLAGS -o "${APP_NAME}" -Xlinker -framework -Xlinker AppKit -Xlinker -framework -Xlinker SwiftUI -Xlinker -framework -Xlinker Foundation $SRC_FILES
    echo "   Binary compiled"
fi

# Clean up
rm -rf "${APP_BUNDLE}" "${DMG_NAME}"

# Create app bundle
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp mac-xbar "${APP_BUNDLE}/Contents/MacOS/"

# Create Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.macxbar.app</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

# Code sign the app (if certificate available)
if security find-identity -v -p codesigning 2>/dev/null | grep -q '"'; then
    echo "==> Signing app bundle..."
    codesign --force --sign - --options runtime --timestamp "${APP_BUNDLE}"
    codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"
else
    echo "==> No signing identity found, skipping code sign"
fi

# Create DMG with proper layout
echo "==> Creating DMG..."
# Create a temp folder with proper layout
DMG_SRC=$(mktemp -d)
cp -R "${APP_BUNDLE}" "${DMG_SRC}/"
ln -s /Applications "${DMG_SRC}/Applications"

hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_SRC}" -ov -format UDZO "${DMG_NAME}"

# Clean up
rm -rf "${DMG_SRC}"

echo "==> DMG created: ${DMG_NAME}"
ls -la "${DMG_NAME}"

# Verify DMG
echo "==> Verifying DMG..."
hdiutil verify "${DMG_NAME}"

echo ""
echo "  Build complete!"
