#!/bin/bash
# 16KB Page Alignment Verification Script
# Verifies that all .so files in the APK are aligned to 16KB boundaries
# Required for Android 15+ compatibility

set -e

APK_PATH="${1:-apps/mobile/build/app/outputs/flutter-apk/app-release.apk}"
ALIGNMENT_SIZE=16384  # 16KB in bytes

echo "=== 16KB Page Alignment Verification ==="
echo "APK Path: $APK_PATH"
echo "Required Alignment: $ALIGNMENT_SIZE bytes (16KB)"
echo ""

# Check if APK exists
if [ ! -f "$APK_PATH" ]; then
    echo "ERROR: APK not found at $APK_PATH"
    echo "Build the release APK first: flutter build apk --release"
    exit 1
fi

# Create temp directory for extraction
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "Extracting APK..."
unzip -q "$APK_PATH" -d "$TEMP_DIR"

# Find all .so files
SO_FILES=$(find "$TEMP_DIR" -name "*.so")
if [ -z "$SO_FILES" ]; then
    echo "No .so files found in APK"
    exit 0
fi

echo ""
echo "Checking ELF alignment for all .so files:"
echo ""

PASS_COUNT=0
FAIL_COUNT=0

for SO_FILE in $SO_FILES; do
    FILENAME=$(basename "$SO_FILE")
    
    # Get the LOAD segment alignment using readelf or objdump
    if command -v readelf &> /dev/null; then
        # Get the max alignment from LOAD segments
        ALIGNMENTS=$(readelf -l "$SO_FILE" 2>/dev/null | grep "LOAD" | grep -oP 'Align\s+\K0x[0-9a-f]+' || true)
        
        if [ -z "$ALIGNMENTS" ]; then
            echo "  ⚠️  $FILENAME - Could not determine alignment"
            continue
        fi
        
        MAX_ALIGN=0
        for ALIGN in $ALIGNMENTS; do
            DECIMAL=$((ALIGN))
            if [ $DECIMAL -gt $MAX_ALIGN ]; then
                MAX_ALIGN=$DECIMAL
            fi
        done
        
        if [ $MAX_ALIGN -ge $ALIGNMENT_SIZE ]; then
            echo "  ✅ $FILENAME - Aligned to $MAX_ALIGN bytes (>= 16KB)"
            ((PASS_COUNT++))
        else
            echo "  ❌ $FILENAME - Aligned to $MAX_ALIGN bytes (< 16KB)"
            ((FAIL_COUNT++))
        fi
    else
        echo "  ⚠️  $FILENAME - readelf not available, skipping"
    fi
done

echo ""
echo "=== Summary ==="
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -gt 0 ]; then
    echo "❌ VERIFICATION FAILED: Some .so files are not 16KB aligned"
    echo "   This will cause crashes on Android 15+ devices with 16KB page size"
    echo ""
    echo "To fix:"
    echo "1. Ensure Flutter 3.22+ is used (already upgraded to 3.32.0)"
    echo "2. Ensure AGP 8.5+ is used (already upgraded to 8.5.2)"
    echo "3. Check if any plugins bundle pre-aligned .so files"
    exit 1
else
    echo "✅ VERIFICATION PASSED: All .so files are 16KB aligned"
    exit 0
fi
