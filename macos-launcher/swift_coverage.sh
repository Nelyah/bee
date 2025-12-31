#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Building and running tests with coverage..."

swift build

xcodebuild test \
    -scheme macos-launcher \
    -destination 'platform=macOS' \
    -enableCodeCoverage YES \
    -derivedDataPath .build/DerivedData \
    2>&1 | xcpretty || true

# Find the latest xcresult bundle
XCRESULT=$(find .build/DerivedData -name "*.xcresult" -type d | head -1)

if [ -z "$XCRESULT" ]; then
    echo "Error: No xcresult bundle found"
    exit 1
fi

echo "Generating coverage report from: $XCRESULT"

# Extract coverage using xcrun
xcrun xccov view --report --json "$XCRESULT" > coverage.json

echo "Coverage report saved to: coverage.json"

# Print summary
echo ""
echo "=== Coverage Summary ==="
xcrun xccov view --report "$XCRESULT" | head -30
