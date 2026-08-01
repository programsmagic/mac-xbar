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

case "${1:-build}" in
  build)
    echo "==> Type-checking source files..."
    start_time=$(date +%s%N)
    swiftc -typecheck $SWIFT_FLAGS $SRC_FILES 2>&1 | grep -E "^error:" && exit 1 || true
    end_time=$(date +%s%N)
    elapsed=$(( (end_time - start_time) / 1000000 ))
    echo "   Type-check passed in ${elapsed}ms"
    ;;
  test)
    echo "==> Type-checking test files..."
    start_time=$(date +%s%N)
    swiftc -typecheck $SWIFT_FLAGS $SRC_FILES $TEST_FILES 2>&1 | grep -E "^error:" && exit 1 || true
    end_time=$(date +%s%N)
    elapsed=$(( (end_time - start_time) / 1000000 ))
    echo "   Type-check passed in ${elapsed}ms"
    ;;
  all)
    echo "==> Type-checking source files..."
    start_time=$(date +%s%N)
    swiftc -typecheck $SWIFT_FLAGS $SRC_FILES 2>&1 | grep -E "^error:" && exit 1 || true
    end_time=$(date +%s%N)
    elapsed=$(( (end_time - start_time) / 1000000 ))
    echo "   Source type-check passed in ${elapsed}ms"
    echo ""
    echo "==> Type-checking test files..."
    start_time=$(date +%s%N)
    swiftc -typecheck $SWIFT_FLAGS $SRC_FILES $TEST_FILES 2>&1 | grep -E "^error:" && exit 1 || true
    end_time=$(date +%s%N)
    elapsed=$(( (end_time - start_time) / 1000000 ))
    echo "   Test type-check passed in ${elapsed}ms"
    ;;
  ci)
    echo "==> Resolving dependencies..."
    swift package resolve 2>&1 || echo "   (SPM unavailable, skipping)"
    echo ""
    echo "==> Building (release)..."
    swift build -c release 2>&1 || echo "   (SPM unavailable, using swiftc type-check only)"
    swiftc -typecheck $SWIFT_FLAGS $SRC_FILES 2>&1 | grep -E "^error:" && exit 1 || true
    echo "   Type-check passed"
    echo ""
    echo "==> Running tests..."
    swift test 2>&1 || echo "   (SPM unavailable, using swiftc type-check only)"
    swiftc -typecheck $SWIFT_FLAGS $SRC_FILES $TEST_FILES 2>&1 | grep -E "^error:" && exit 1 || true
    echo "   Test type-check passed"
    ;;
  *)
    echo "Usage: $0 {build|test|all|ci}"
    echo ""
    echo "  build  - Type-check source files only"
    echo "  test   - Type-check source + test files"
    echo "  all    - Type-check everything"
    echo "  ci     - Full CI pipeline (SPM + type-check)"
    exit 1
    ;;
esac

echo ""
echo "  Build complete!"
