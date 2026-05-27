# Android 15+ 16KB Page Alignment Guide

## Background

Starting November 2024, Google Play requires all apps targeting Android 15+ to support 16KB page size alignment. This is a breaking change for apps with native libraries (.so files) that are not properly aligned.

## Requirements

- Flutter 3.22.0+ (we use 3.32.0)
- Android Gradle Plugin 8.5.1+ (we use 8.5.2)
- Gradle 8.7+ (we use 8.7)
- NDK r28+ (managed by Flutter)

## Verification

Run the verification script after building a release APK:

```bash
# Build release APK
flutter build apk --release

# Verify alignment
./scripts/check_elf_alignment.sh
```

Expected output:
```
✅ VERIFICATION PASSED: All .so files are 16KB aligned
```

## Troubleshooting

### If verification fails:

1. **Check Flutter version**:
   ```bash
   flutter --version
   # Should show 3.32.0 or higher
   ```

2. **Check AGP version**:
   ```bash
   grep "com.android.application" apps/mobile/android/settings.gradle
   # Should show version "8.5.2"
   ```

3. **Check Gradle version**:
   ```bash
   grep "distributionUrl" apps/mobile/android/gradle/wrapper/gradle-wrapper.properties
   # Should show gradle-8.7
   ```

4. **Check plugin compatibility**:
   Some Flutter plugins may bundle pre-compiled .so files that are not 16KB aligned. Check for updates to these plugins.

### Common problematic plugins:
- Camera plugins
- ML/Vision plugins
- Video/Audio codecs
- Crypto SDKs

## CI Integration

The verification script can be integrated into CI:

```yaml
- name: Build Android APK
  run: flutter build apk --release

- name: Verify 16KB alignment
  run: ./scripts/check_elf_alignment.sh
```

## References

- [Google Play 16KB Page Size Requirement](https://developer.android.com/guide/practices/page-sizes)
- [Flutter 16KB Page Size Support](https://docs.flutter.dev/release/breaking-changes/android-page-size)
