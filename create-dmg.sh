#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="mac-xbar"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
VERSION="1.1.0"
ICON_NAME="mac-xbar.icns"
ICON_SRC="xbarapp.com/public/img/xbar-2048.png"
ICONSET_DIR="${APP_BUNDLE}/Contents/Resources/mac-xbar.iconset"

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

# Generate app icon from PNG source
if [ -f "${ICON_SRC}" ]; then
    rm -rf "${ICONSET_DIR}"
    mkdir -p "${ICONSET_DIR}"
    for size in 16 32 64 128 256 512 1024; do
        half=$((size * 2))
        sips -z $size $size "${ICON_SRC}" --out "${ICONSET_DIR}/icon_${size}x${size}.png" 2>/dev/null
        if [ $size -le 512 ]; then
            sips -z $half $half "${ICON_SRC}" --out "${ICONSET_DIR}/icon_${size}x${size}@2x.png" 2>/dev/null
        fi
    done
    iconutil -c icns "${ICONSET_DIR}" -o "${APP_BUNDLE}/Contents/Resources/${ICON_NAME}" 2>/dev/null
    rm -rf "${ICONSET_DIR}"
    echo "==> Icon generated"
fi

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
    <key>CFBundleIconFile</key>
    <string>${ICON_NAME}</string>
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

# Code sign the app (ad-hoc for development, proper cert for release)
echo "==> Signing app bundle..."
codesign --force --sign - --options runtime --timestamp "${APP_BUNDLE}" 2>/dev/null || \
  codesign --force --sign - --preserve-metadata=identifier,entitlements,flags --timestamp "${APP_BUNDLE}" 2>/dev/null || \
  echo "   (ad-hoc signing skipped)"

# Verify signing
codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}" 2>/dev/null || \
  echo "   (signature verification skipped)"

# Create DMG with proper layout
echo "==> Creating DMG..."
DMG_SRC=$(mktemp -d)
cp -R "${APP_BUNDLE}" "${DMG_SRC}/"
ln -s /Applications "${DMG_SRC}/Applications"

hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_SRC}" -ov -format UDZO "${DMG_NAME}"

rm -rf "${DMG_SRC}"

echo "==> DMG created: ${DMG_NAME}"
ls -la "${DMG_NAME}"

echo "==> Verifying DMG..."
hdiutil verify "${DMG_NAME}"

echo ""
echo "  Build complete!"
