#!/bin/bash

echo "Starting build verification for finance_app..."

# Navigate to mobile app directory
cd /vol3/1000/docker/opencode/workspace/test1/apps/mobile

# Check if pubspec.yaml exists
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ pubspec.yaml not found in apps/mobile"
    exit 1
fi

echo "✅ Found pubspec.yaml"

# Check for Dart syntax errors using dart analyze
echo ""
echo "Checking for Dart syntax errors..."
dart analyze --fatal-infos 2>&1 | head -50

# If dart analyze is not available, try a different approach
if [ $? -eq 127 ]; then
    echo "dart analyze not available, checking files manually..."
    
    # Check for common syntax issues
    errors=0
    
    # Check all Dart files for basic syntax
    while IFS= read -r file; do
        # Check for common errors
        if grep -q "Platform\.isWeb" "$file" 2>/dev/null; then
            echo "⚠️  $file: Platform.isWeb should use kIsWeb"
            ((errors++))
        fi
        
        if grep -q "Icons\.template" "$file" 2>/dev/null; then
            echo "⚠️  $file: Icons.template doesn't exist"
            ((errors++))
        fi
        
    done < <(find lib -name "*.dart" -type f)
    
    if [ $errors -eq 0 ]; then
        echo "✅ No common syntax errors found"
    else
        echo "❌ Found $errors errors"
    fi
fi

echo ""
echo "Build verification complete!"
