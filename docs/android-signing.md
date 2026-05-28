# Android Release Signing Configuration

This document describes how to configure release signing for Android builds.

## Prerequisites

- Java JDK 17 or later
- Android SDK
- Flutter 3.32.0+

## Generate Release Keystore

### Option 1: Generate new keystore (recommended for new projects)

```bash
cd apps/mobile/android/app

keytool -genkey -v -keystore release-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias finance-app-release
```

You will be prompted to enter:
- Keystore password
- Key password
- Your name, organization, etc.

### Option 2: Use existing keystore

If you have an existing keystore file, copy it to `apps/mobile/android/app/release-keystore.jks`.

## Create key.properties

Create a file `android/key.properties` (not in version control - already in .gitignore):

```properties
storePassword=<your-keystore-password>
keyPassword=<your-key-password>
keyAlias=finance-app-release
storeFile=release-keystore.jks
```

**⚠️ IMPORTANT: Never commit `key.properties` or keystore files to version control!**

## Configure build.gradle

The `android/app/build.gradle` has been updated with signing configuration:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...
    
    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
                storePassword keystoreProperties['storePassword']
            }
        }
    }
    
    buildTypes {
        release {
            // Signing with release config if key.properties exists, otherwise debug keys
            signingConfig keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug
            // Enable minification for release builds
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

**Note**: The configuration automatically falls back to debug signing if `key.properties` doesn't exist, allowing developers to build without setting up release keys locally.

## Build Release APK

```bash
cd apps/mobile
flutter build apk --release
```

The signed APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

## Build Release App Bundle (for Play Store)

```bash
cd apps/mobile
flutter build appbundle --release
```

The signed AAB will be at: `build/app/outputs/bundle/release/app-release.aab`

## CI/CD Configuration

For GitHub Actions, store the keystore as a base64-encoded secret:

1. Encode the keystore:
```bash
base64 -i release-keystore.jks | pbcopy  # macOS
# or
base64 -w 0 release-keystore.jks  # Linux
```

2. Add secrets to GitHub repository:
   - `ANDROID_KEYSTORE_BASE64`: Base64-encoded keystore file
   - `ANDROID_KEYSTORE_PASSWORD`: Keystore password
   - `ANDROID_KEY_ALIAS`: Key alias (default: `finance-app-release`)
   - `ANDROID_KEY_PASSWORD`: Key password

3. Update `.github/workflows/build-release.yml` to use these secrets.

## Debug Keystore (for development)

For debug builds, Flutter uses an automatically-generated debug keystore at:
- Linux/macOS: `~/.android/debug.keystore`
- Windows: `%USERPROFILE%\.android\debug.keystore`

## Troubleshooting

### "Keystore was tampered with, or password was incorrect"
- Verify the keystore password in `key.properties`
- Try opening the keystore manually: `keytool -list -v -keystore release-keystore.jks`

### "Failed to read key from keystore"
- Verify the key alias matches what you created
- List keys in keystore: `keytool -list -v -keystore release-keystore.jks`

### Build fails with signing errors
- Ensure `key.properties` is in `android/` directory (not `android/app/`)
- Check file paths are relative to `android/app/build.gradle`

## Security Best Practices

1. **Never commit secrets to version control**
   - Keystore files (.jks, .keystore)
   - key.properties file
   - Passwords in any file

2. **Use different keystores for debug and release**

3. **Backup your keystore securely**
   - Store in encrypted cloud storage
   - Keep multiple copies
   - Document passwords in a password manager

4. **Use strong passwords**
   - Minimum 16 characters
   - Mix of letters, numbers, symbols

5. **Set appropriate validity period**
   - 25+ years for apps on Play Store
   - Google Play requires validity until at least October 2033

## Play Store Upload

Once you have a signed AAB:

1. Go to [Google Play Console](https://play.google.com/console)
2. Create a new app or select existing
3. Navigate to Release → Testing/Production
4. Upload the signed AAB
5. Fill in release notes and roll out

## Signing for Different Build Flavors

If using multiple build flavors (e.g., dev, staging, prod), create separate signing configs:

```gradle
android {
    flavorDimensions = ["environment"]
    productFlavors {
        dev {
            dimension "environment"
            signingConfig signingConfigs.debug
        }
        prod {
            dimension "environment"
            signingConfig signingConfigs.release
        }
    }
}
```
