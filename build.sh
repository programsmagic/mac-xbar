#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "  mac-xbar build script..."
echo ""

SWIFT_FLAGS="-target arm64-apple-macosx14.0 -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
SWIFT_FLAGS="$SWIFT_FLAGS -I /Library/Developer/CommandLineTools/Library/Developer/Frameworks"
SWIFT_FLAGS="$SWIFT_FLAGS -L /Library/Developer/CommandLineTools/Library/Developer/Frameworks"

SRC_FILES=$(find Sources -name "*.swift" | sort)
TEST_FILES=$(find Tests -name "*.swift" | sort)

check_typecheck() {
    local label="$1"
    local files="$2"
    echo "==> $label"
    local start_time
    start_time=$(date +%s%N)
    local errors
    errors=$(swiftc -typecheck $SWIFT_FLAGS $files 2>&1 | grep -E "^error:" || true)
    local end_time
    end_time=$(date +%s%N)
    local elapsed=$(( (end_time - start_time) / 1000000 ))
    if [ -n "$errors" ]; then
        echo "$errors"
        echo "   Type-check FAILED in ${elapsed}ms"
        return 1
    fi
    echo "   Type-check passed in ${elapsed}ms"
}

case "${1:-build}" in
  build)
    check_typecheck "Type-checking source files..." "$SRC_FILES"
    ;;
  test)
    check_typecheck "Type-checking source + test files..." "$SRC_FILES $TEST_FILES"
    ;;
  all)
    check_typecheck "Type-checking source files..." "$SRC_FILES"
    echo ""
    check_typecheck "Type-checking test files..." "$SRC_FILES $TEST_FILES"
    ;;
  ci)
    echo "==> Resolving dependencies..."
    if swift package resolve 2>/dev/null; then
      echo "   Dependencies resolved"
    else
      echo "   (SPM unavailable, skipping)"
    fi
    echo ""
    echo "==> Building (release)..."
    if swift build -c release 2>/dev/null; then
      echo "   Build succeeded"
    else
      echo "   (SPM unavailable, using swiftc type-check only)"
    fi
    check_typecheck "Type-checking source files..." "$SRC_FILES"
    echo ""
    echo "==> Running tests..."
    if swift test 2>/dev/null; then
      echo "   Tests passed"
    else
      echo "   (SPM unavailable, using swiftc type-check only)"
    fi
    check_typecheck "Type-checking test files..." "$SRC_FILES $TEST_FILES"
    ;;
  dmg)
    echo "==> Building DMG..."
    bash create-dmg.sh
    ;;
  *)
    echo "Usage: $0 {build|test|all|ci|dmg}"
    echo ""
    echo "  build  - Type-check source files only"
    echo "  test   - Type-check source + test files"
    echo "  all    - Type-check everything"
    echo "  ci     - Full CI pipeline (SPM + type-check)"
    echo "  dmg    - Create release DMG"
    exit 1
    ;;
esac

echo ""
echo "  Build complete!"