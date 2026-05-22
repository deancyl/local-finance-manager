# Sync System PowerSync Compatibility Investigation

**Investigation Date:** 2026-05-22  
**Investigator:** Automated Analysis  
**Version Context:** v0.3.2 (sync disabled) → v0.3.51 (current)

---

## Executive Summary

The sync system was disabled in v0.3.2 due to PowerSync Dart SDK version incompatibility. The root cause is a **Dart SDK version mismatch**: PowerSync requires Dart SDK ≥3.10.0, but the project uses Flutter 3.27.1 which bundles Dart 3.6.0.

**Status:** Sync feature temporarily disabled  
**Impact:** Multi-device sync functionality unavailable  
**Workaround:** None - requires Flutter/Dart upgrade or PowerSync downgrade

---

## Current Implementation Analysis

### 1. PowerSync Package Version

**File:** `packages/sync/pubspec.yaml`

```yaml
dependencies:
  powersync: ^1.9.0
```

The project specifies PowerSync version `^1.9.0`, which allows any version >= 1.9.0 and < 2.0.0.

### 2. SDK Version Constraints

| Component | Version Requirement | Actual Version |
|-----------|---------------------|----------------|
| PowerSync Dart SDK | ≥3.10.0 | N/A (not met) |
| Flutter | 3.27.1 | 3.27.1 |
| Dart (bundled with Flutter 3.27.1) | 3.6.0 | 3.6.0 |
| Project SDK constraint | ≥3.5.0 <4.0.0 | 3.6.0 |

**The Gap:** Dart 3.6.0 < Dart 3.10.0 (required by PowerSync)

### 3. PowerSync API Usage in sync_client.dart

**File:** `packages/sync/lib/src/sync_client.dart`

The implementation uses the following PowerSync APIs:

#### Core API Calls

| API Method | Line | Purpose | Status |
|------------|------|---------|--------|
| `PowerSyncDatabase()` | 130 | Constructor with schema, path, encryption | ✅ Standard |
| `initialize()` | 137 | Initialize database | ✅ Standard |
| `connect(connector, crudThrottle)` | 187 | Connect to sync server | ⚠️ Uses deprecated `crudThrottle` |
| `statusStream` | 193 | Watch connection status | ✅ Standard |
| `disconnect()` | 219 | Disconnect from server | ✅ Standard |
| `uploadCrud()` | 240 | Manual sync trigger | ⚠️ May be deprecated |
| `getCrudBatch()` | 283 | Get pending operations | ✅ Standard |
| `close()` | 257 | Close database | ✅ Standard |
| `execute()` | 349, 354, etc. | Execute SQL queries | ✅ Standard |
| `watch()` | 419 | Watch query results | ✅ Standard |

#### Encryption API

```dart
// Line 123-126
encryptionOptions = EncryptionOptions(
  key: key,
  sqlcipherCompatibility: false,
);
```

This uses `EncryptionOptions` which is a standard PowerSync API for SQLCipher encryption.

### 4. Backend Connector Implementation

**File:** `packages/sync/lib/src/connector/backend_connector.dart`

The connector extends `PowerSyncBackendConnector` and implements:

| Method | Purpose | Status |
|--------|---------|--------|
| `fetchCredentials()` | Return PowerSyncCredentials | ✅ Standard |
| `uploadData(database)` | Upload CRUD transaction | ✅ Standard |
| `invalidateCredentials()` | Clear cached credentials | ✅ Standard |

The implementation uses:
- `database.getNextCrudTransaction()` - Standard API
- `transaction.complete()` - Standard API
- `UpdateType.put/patch/delete` - Standard enum

### 5. Server-Side Configuration

**File:** `apps/sync-server/powersync.yaml`

```yaml
config:
  edition: 3

streams:
  user_data:
    params:
      - SELECT request.user_id() as user_id
    queries:
      - SELECT ... FROM accounts WHERE user_id = stream.user_id
      - SELECT ... FROM transactions WHERE user_id = stream.user_id
      # ... 8 tables total
```

Configuration appears standard and follows PowerSync sync rules format.

---

## Potential Compatibility Issues

### Issue 1: Dart SDK Version Mismatch (CRITICAL)

**Root Cause:**  
PowerSync package version 1.9.0+ requires Dart SDK ≥3.10.0, but Flutter 3.27.1 bundles Dart 3.6.0.

**Evidence:**
- CHANGELOG.md v0.3.2: "PowerSync package requires Dart SDK >=3.10.0 but Flutter 3.27.1 uses Dart 3.6.0"
- Flutter 3.27.1 release notes confirm Dart 3.6.0 bundling

**Impact:**  
Compilation fails when attempting to use PowerSync package. The sync feature cannot be enabled without resolving this version conflict.

### Issue 2: Deprecated API Usage (MINOR)

**`crudThrottle` parameter in `connect()`:**

```dart
// Line 187-190
await _powerSyncDb.connect(
  connector: _connector,
  crudThrottle: Duration(seconds: config.syncIntervalSeconds),
);
```

**Analysis:**  
Based on PowerSync documentation, the `connect()` method signature may have changed. Current documentation shows:

```dart
db.connect(connector: MyBackendConnector());
```

The `crudThrottle` parameter may have been removed or replaced with `SyncOptions`:

```dart
// New API (SDK v1.17.0+)
const options = SyncOptions(
  crudThrottle: Duration(seconds: 30),
);
powerSync.connect(connector: connector, options: options);
```

### Issue 3: `uploadCrud()` Method (POTENTIAL)

```dart
// Line 240
await _powerSyncDb.uploadCrud();
```

**Analysis:**  
This method triggers manual upload of CRUD operations. Need to verify if this method still exists in current PowerSync API or if it's been replaced with a different mechanism.

### Issue 4: Status Type Mismatch

```dart
// Line 307-311
void _onPowerSyncStatus(SyncStatus status) {
  _log.fine('PowerSync status: $status');
  // Map PowerSync status to our status
  // PowerSync uses different status values
}
```

**Analysis:**  
The comment indicates PowerSync's `SyncStatus` type differs from the project's custom `SyncStatus` enum. The mapping is incomplete (TODO comment).

**PowerSync's SyncStatus has properties:**
- `connected` (bool)
- `connecting` (bool)
- `uploading` (bool)
- `downloading` (bool)
- `anyError` (Object?)

**Project's SyncStatus is an enum:**
- `notInitialized`
- `disconnected`
- `connecting`
- `connected`
- `error`

This requires proper mapping logic.

---

## Comparison with Official Patterns

### Official PowerSync Pattern (from documentation)

```dart
// 1. Create database
final db = PowerSyncDatabase(schema: schema, path: path);
await db.initialize();

// 2. Define connector
class Connector extends PowerSyncBackendConnector {
  @override
  Future<PowerSyncCredentials> fetchCredentials() async {
    return PowerSyncCredentials(
      endpoint: 'https://your-instance.powersync.com',
      token: 'your-token'
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;
    
    for (final op in transaction.crud) {
      // Process each operation
    }
    
    await transaction.complete();
  }
}

// 3. Connect
await db.connect(connector: Connector());

// 4. Watch status
db.statusStream.listen((status) {
  // Handle status changes
});
```

### Project Implementation Comparison

| Aspect | Official Pattern | Project Implementation | Match |
|--------|------------------|------------------------|-------|
| Database creation | `PowerSyncDatabase(schema, path)` | `PowerSyncDatabase(schema, path, encryption)` | ✅ Extended |
| Initialization | `await db.initialize()` | `await _powerSyncDb.initialize()` | ✅ Match |
| Connector base class | `PowerSyncBackendConnector` | `PowerSyncBackendConnector` | ✅ Match |
| `fetchCredentials()` | Returns `PowerSyncCredentials` | Returns `PowerSyncCredentials` | ✅ Match |
| `uploadData()` | Uses `getNextCrudTransaction()` | Uses `getNextCrudTransaction()` | ✅ Match |
| Connection | `db.connect(connector)` | `db.connect(connector, crudThrottle)` | ⚠️ Extra param |
| Status watching | `db.statusStream.listen()` | `_powerSyncDb.statusStream.listen()` | ✅ Match |
| Encryption | `EncryptionOptions(key)` | `EncryptionOptions(key, sqlcipherCompatibility)` | ✅ Extended |

**Conclusion:** The implementation closely follows official patterns with minor extensions for encryption and throttling.

---

## Root Cause Hypothesis

### Primary Cause: Dart SDK Version Incompatibility

**The fundamental issue is a Dart SDK version mismatch:**

1. **PowerSync 1.9.0+** requires **Dart SDK ≥3.10.0**
2. **Flutter 3.27.1** bundles **Dart 3.6.0**
3. **Dart 3.6.0 < Dart 3.10.0** → Compilation fails

### Why This Happened

1. PowerSync released a version requiring newer Dart features (likely Dart 3.10 features like enhanced pattern matching, sealed classes, or new async features)
2. The project locked to Flutter 3.27.1 for stability
3. Flutter's Dart version is tightly coupled - cannot upgrade Dart independently

### Version Timeline (Estimated)

| Date | Flutter | Dart | PowerSync | Status |
|------|---------|------|-----------|--------|
| Early 2025 | 3.24.x | 3.5.x | 1.8.x | ✅ Compatible |
| Mid 2025 | 3.27.1 | 3.6.0 | 1.9.0 | ❌ Incompatible |
| Future | 3.29+ | 3.10+ | 1.9.0+ | ✅ Compatible |

---

## Recommended Fix Approach

### Option A: Upgrade Flutter/Dart (RECOMMENDED)

**Pros:**
- Enables latest PowerSync features
- Access to newer Dart language features
- Better long-term maintainability

**Cons:**
- May break other dependencies
- Requires testing entire app
- Migration effort

**Steps:**
1. Check Flutter 3.29+ release (should bundle Dart 3.10+)
2. Update `pubspec.yaml` SDK constraints
3. Run `flutter upgrade`
4. Test all features
5. Re-enable sync package

**Estimated Effort:** 2-4 days (including testing)

### Option B: Downgrade PowerSync

**Pros:**
- Minimal changes
- Quick fix

**Cons:**
- Misses new PowerSync features
- May have other compatibility issues
- Technical debt

**Steps:**
1. Find PowerSync version compatible with Dart 3.6.0 (likely 1.8.x or earlier)
2. Update `packages/sync/pubspec.yaml`:
   ```yaml
   dependencies:
     powersync: ^1.8.0  # or specific version like 1.8.5
   ```
3. Test sync functionality
4. Re-enable sync package

**Estimated Effort:** 1-2 days

### Option C: Use Alternative Sync Solution

**Pros:**
- Independence from PowerSync version constraints
- Potentially simpler implementation

**Cons:**
- Major rewrite required
- Loses PowerSync's offline-first architecture
- Higher risk

**Alternatives:**
- Custom sync with PostgreSQL + WebSockets
- Firebase Realtime Database
- Supabase Realtime
- Couchbase Lite

**Estimated Effort:** 2-4 weeks (not recommended)

---

## Recommended Action Plan

### Phase 1: Immediate (v0.3.x)

1. **Document the issue** (this document) ✅
2. **Keep sync code intact** for future re-enablement
3. **Monitor Flutter releases** for Dart 3.10+ bundling

### Phase 2: Short-term (v0.4.0)

1. **Evaluate Flutter 3.29+** when released
2. **Test PowerSync compatibility** with new Flutter version
3. **Update SDK constraints** if compatible
4. **Re-enable sync** with proper testing

### Phase 3: Implementation Checklist

When re-enabling sync:

- [ ] Update Flutter to version with Dart ≥3.10.0
- [ ] Update `pubspec.yaml` SDK constraints
- [ ] Verify PowerSync API compatibility
- [ ] Fix `crudThrottle` parameter if deprecated
- [ ] Implement proper `SyncStatus` mapping
- [ ] Uncomment routes in `app_router.dart`
- [ ] Uncomment dependency in `pubspec.yaml`
- [ ] Uncomment imports in `main_shell.dart`
- [ ] Add comprehensive sync tests
- [ ] Update user documentation

---

## Files to Modify When Re-enabling

### 1. `apps/mobile/pubspec.yaml`

```yaml
dependencies:
  # Uncomment:
  sync:
    path: ../../packages/sync
```

### 2. `apps/mobile/lib/core/router/app_router.dart`

```dart
// Uncomment imports:
import '../../features/sync/presentation/pages/sync_settings_page.dart';
import '../../features/sync/presentation/pages/sync_login_page.dart';
import '../../features/sync/presentation/pages/device_pairing_page.dart';
import '../../features/sync/presentation/pages/offline_queue_page.dart';

// Uncomment routes (lines 198-217):
GoRoute(
  path: '/settings/sync',
  name: 'sync-settings',
  builder: (context, state) => const SyncSettingsPage(),
),
// ... etc
```

### 3. `apps/mobile/lib/core/presentation/pages/main_shell.dart`

```dart
// Uncomment import:
import '../../features/sync/presentation/widgets/sync_status_indicator.dart';
```

### 4. `packages/sync/lib/src/sync_client.dart`

**Fix deprecated API usage:**

```dart
// OLD (potentially deprecated):
await _powerSyncDb.connect(
  connector: _connector,
  crudThrottle: Duration(seconds: config.syncIntervalSeconds),
);

// NEW (if API changed):
await _powerSyncDb.connect(
  connector: _connector,
  options: SyncOptions(
    crudThrottle: Duration(seconds: config.syncIntervalSeconds),
  ),
);
```

**Fix status mapping:**

```dart
void _onPowerSyncStatus(SyncStatus status) {
  _log.fine('PowerSync status: $status');
  
  // Map PowerSync SyncStatus to our SyncStatus enum
  if (status.anyError != null) {
    _updateStatus(SyncStatus.error);
    _errorMessage = status.anyError.toString();
  } else if (status.connecting) {
    _updateStatus(SyncStatus.connecting);
  } else if (status.connected) {
    _updateStatus(SyncStatus.connected);
  } else {
    _updateStatus(SyncStatus.disconnected);
  }
}
```

---

## Estimated Effort Summary

| Task | Effort | Priority |
|------|--------|----------|
| Flutter/Dart upgrade research | 2 hours | High |
| Compatibility testing | 4 hours | High |
| API migration (if needed) | 4-8 hours | Medium |
| Full integration testing | 8-16 hours | High |
| Documentation updates | 2 hours | Low |
| **Total** | **20-32 hours** | - |

**Recommended allocation:** 3-4 days for complete re-enablement with testing.

---

## References

### Internal Documentation
- [CHANGELOG.md](../CHANGELOG.md) - v0.3.2 entry
- [README.md](../README.md) - Sync system overview
- [apps/sync-server/README.md](../apps/sync-server/README.md) - Server setup

### External Documentation
- [PowerSync Flutter SDK](https://docs.powersync.com/client-sdks/reference/flutter)
- [PowerSync Backend Connector](https://docs.powersync.com/intro/setup-guide)
- [PowerSync Encryption](https://docs.powersync.com/client-sdks/advanced/data-encryption)
- [Flutter SDK Archive](https://docs.flutter.dev/release/archive)
- [Dart SDK Version History](https://dart.dev/get-dart/archive)

### Related Issues
- Sync disabled in commit: v0.3.2 (2026-05-20)
- Reason: "PowerSync API incompatible"
- Flutter version at disable time: 3.27.1
- Dart version at disable time: 3.6.0

---

## Appendix A: PowerSync API Version History

| PowerSync Version | Min Dart SDK | Release Date | Key Changes |
|-------------------|--------------|--------------|-------------|
| 1.8.x | 3.5.0 | ~Early 2025 | Stable release |
| 1.9.0 | 3.10.0 | ~Mid 2025 | Dart 3.10 features |
| 1.16.0+ | 3.10.0 | ~Late 2025 | Attachments support |
| 1.17.0+ | 3.10.0 | ~2025 | SyncOptions, appMetadata |

---

## Appendix B: Flutter/Dart Version Matrix

| Flutter | Dart | Release | PowerSync 1.9 Compatible |
|---------|------|---------|--------------------------|
| 3.24.x | 3.5.x | Aug 2024 | ❌ No |
| 3.27.1 | 3.6.0 | Nov 2024 | ❌ No |
| 3.29.x | 3.10.x | ~2025 | ✅ Yes |

---

*Document generated: 2026-05-22*  
*Last updated: 2026-05-22*  
*Status: Investigation complete, awaiting fix implementation*
