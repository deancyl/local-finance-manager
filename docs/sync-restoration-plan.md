# Sync Restoration Plan

**Investigation Version:** v0.3.177  
**Investigation Date:** 2026-05-29  
**Status:** Blocked - PowerSync Dart SDK Incompatibility

---

## Executive Summary

The multi-device sync feature was disabled in v0.3.2 due to a critical Dart SDK version incompatibility with the PowerSync package. This document outlines the root cause, available restoration options, and recommended path forward.

**Current Status:**
- ✅ Sync server infrastructure ready (Dart Frog + PostgreSQL)
- ✅ Sync client code intact but disabled
- ❌ PowerSync Dart SDK version incompatible with current Flutter
- ❌ Multi-device sync functionality unavailable

---

## Root Cause Analysis

### The Problem

**PowerSync Package Requirement vs. Flutter Dart Version**

| Component | Required Version | Actual Version | Status |
|-----------|------------------|----------------|--------|
| PowerSync Dart SDK | ≥ 3.10.0 | N/A | ❌ Not met |
| Flutter (current) | N/A | 3.32.0 | ✅ Current |
| Dart SDK (Flutter 3.32.0) | N/A | 3.6.0 | ❌ Too old |
| Dart SDK Gap | ≥ 3.10.0 | 3.6.0 | **4 minor versions** |

**Impact:** The PowerSync package (version 1.9.0+) requires Dart SDK features introduced in version 3.10.0, but Flutter 3.32.0 bundles Dart 3.6.0. This makes it impossible to compile the sync code.

### Version History Context

| Flutter Version | Bundled Dart | PowerSync Compatible | Notes |
|----------------|--------------|---------------------|-------|
| 3.27.1 | 3.6.0 | ❌ No | Version when sync was disabled |
| 3.32.0 | 3.6.0 | ❌ No | Current version |
| 3.29+ | 3.10+ | ✅ Yes | Required for PowerSync 1.9+ |

**The Issue:** Flutter 3.32.0 still uses Dart 3.6.0, not Dart 3.10+. There's a discrepancy in the Flutter/Dart versioning that needs clarification.

### Why PowerSync Requires Dart 3.10+

PowerSync 1.9.0+ likely uses Dart 3.10 features such as:
- Enhanced pattern matching
- Sealed classes improvements
- New async/await features
- Improved type system capabilities
- Performance optimizations

---

## PowerSync Integration Details

### Current Implementation Status

**File:** `packages/sync/lib/src/sync_client.dart`

The sync client implementation follows PowerSync best practices:

1. **Database Initialization:** ✅ Standard
   ```dart
   _powerSyncDb = PowerSyncDatabase(
     schema: _schema,
     path: dbPath,
     encryptionOptions: encryptionOptions,
   );
   await _powerSyncDb.initialize();
   ```

2. **Backend Connector:** ✅ Standard
   - Extends `PowerSyncBackendConnector`
   - Implements `fetchCredentials()` and `uploadData()`
   - Uses standard `getNextCrudTransaction()` API

3. **Connection Management:** ⚠️ Potential Issue
   - Uses `crudThrottle` parameter which may be deprecated
   - Needs verification against current PowerSync API

4. **Status Monitoring:** ⚠️ Incomplete
   - PowerSync's `SyncStatus` differs from project's enum
   - Mapping logic has TODO comments

5. **Encryption:** ✅ Implemented
   - AES-256-GCM encryption
   - PBKDF2 key derivation (100k iterations)

### Server Infrastructure

**Status:** ✅ Ready

The sync server (`apps/sync-server/`) is fully implemented:
- Dart Frog backend
- PostgreSQL database
- JWT authentication (7-day tokens)
- Docker Compose setup
- PowerSync configuration (`powersync.yaml`)
- 70+ unit tests passing

### Disabled Code Locations

The sync feature was disabled by commenting out code in:

1. **`apps/mobile/pubspec.yaml`** (line 71-72)
   ```yaml
   sync:
     path: ../../packages/sync
   ```

2. **`apps/mobile/lib/core/router/app_router.dart`**
   - Import statements for sync pages (lines 8-11)
   - Sync route definitions (lines 198-217)

3. **`apps/mobile/lib/core/presentation/pages/main_shell.dart`**
   - Sync status indicator import

4. **`apps/mobile/lib/features/settings/presentation/pages/settings_page.dart`**
   - Sync settings menu item

---

## Restoration Options

### Option A: Flutter Upgrade to Dart 3.10+ ✅ RECOMMENDED

**Description:** Wait for or upgrade to Flutter version that bundles Dart 3.10.0 or later.

**Pros:**
- ✅ Enables latest PowerSync features and bug fixes
- ✅ Access to newer Dart language features
- ✅ Better long-term maintainability
- ✅ Official, supported path

**Cons:**
- ⚠️ May introduce breaking changes in other dependencies
- ⚠️ Requires comprehensive testing of entire app
- ⚠️ Migration effort and risk

**Implementation Steps:**
1. Research Flutter release schedule for Dart 3.10+ bundling
2. Check Flutter beta/dev channels for availability
3. Update `pubspec.yaml` SDK constraints:
   ```yaml
   environment:
     sdk: '>=3.10.0 <4.0.0'
   ```
4. Upgrade Flutter: `flutter upgrade` (or switch to beta channel)
5. Run `flutter pub get` to resolve dependencies
6. Fix any breaking changes from Flutter/Dart upgrade
7. Verify PowerSync API compatibility
8. Re-enable sync package and routes
9. Update API usage if PowerSync changed:
   ```dart
   // Potential API change for connect():
   await _powerSyncDb.connect(
     connector: _connector,
     options: SyncOptions(
       crudThrottle: Duration(seconds: config.syncIntervalSeconds),
     ),
   );
   ```
10. Complete status mapping:
    ```dart
    void _onPowerSyncStatus(SyncStatus status) {
      if (status.anyError != null) {
        _updateStatus(SyncStatus.error);
      } else if (status.connecting) {
        _updateStatus(SyncStatus.connecting);
      } else if (status.connected) {
        _updateStatus(SyncStatus.connected);
      } else {
        _updateStatus(SyncStatus.disconnected);
      }
    }
    ```
11. Comprehensive testing (unit, integration, multi-device)
12. Update user documentation

**Estimated Effort:** 3-5 days (including testing and potential migration fixes)

**Risk Level:** Medium (Flutter upgrade may affect other parts of the app)

---

### Option B: Downgrade PowerSync Package ⚠️ FALLBACK

**Description:** Find and use a PowerSync version compatible with Dart 3.6.0.

**Pros:**
- ✅ Minimal changes required
- ✅ Quick implementation
- ✅ No Flutter upgrade needed

**Cons:**
- ❌ Misses new PowerSync features and improvements
- ❌ May have other compatibility issues
- ❌ Technical debt accumulation
- ❌ Uncertain long-term support
- ❌ May not find compatible version

**Implementation Steps:**
1. Research PowerSync version history:
   - Check pub.dev for PowerSync versions
   - Look for version compatible with Dart 3.6.0
   - Likely candidates: 1.8.x or earlier
2. Update `packages/sync/pubspec.yaml`:
   ```yaml
   dependencies:
     powersync: ^1.8.0  # or specific: 1.8.5
     drift_sqlite_async: ^0.3.0  # may need adjustment
   ```
3. Run `flutter pub get` in packages/sync
4. Test sync functionality
5. Verify no other API breaking changes
6. Re-enable sync routes and imports
7. Testing and documentation

**Estimated Effort:** 1-2 days

**Risk Level:** Medium-High (older PowerSync may have bugs or security issues)

**Fallback If Option A Blocked:** If Flutter upgrade path is not viable in the short term, this provides immediate sync functionality.

---

### Option C: Alternative Sync Solution ❌ NOT RECOMMENDED

**Description:** Replace PowerSync with a different sync technology.

**Potential Alternatives:**
1. **Custom WebSocket + PostgreSQL Sync**
   - Build from scratch
   - Full control but high complexity

2. **Firebase Realtime Database / Firestore**
   - Mature, well-supported
   - Google cloud dependency (conflicts with local-first principle)

3. **Supabase Realtime**
   - Open-source alternative
   - PostgreSQL-based
   - Good fit for local-first architecture

4. **Couchbase Lite**
   - Mature offline-first database
   - Cross-platform sync
   - Different data model (JSON vs SQL)

5. **Realm Database**
   - Mobile-first database
   - Built-in sync (MongoDB Atlas)
   - Different paradigm (object database)

**Pros:**
- ✅ Independence from PowerSync version constraints
- ✅ Potentially simpler implementation
- ✅ Different feature sets may suit needs better

**Cons:**
- ❌ Major rewrite required (weeks, not days)
- ❌ Loses PowerSync's offline-first architecture
- ❌ Higher risk of bugs in new implementation
- ❌ Abandons existing tested sync code
- ❌ May conflict with local-first/privacy requirements (Firebase)

**Estimated Effort:** 2-4 weeks (complete rewrite)

**Risk Level:** High (major architectural change)

**Recommendation:** ❌ Not recommended unless Options A and B both fail. The existing PowerSync implementation is well-architected and tested; abandoning it should be a last resort.

---

## Recommended Action Plan

### Phase 1: Clarification (v0.3.177+) - IMMEDIATE

**Goal:** Resolve Flutter/Dart version confusion

**Tasks:**
1. ✅ Create this investigation document
2. ⬜ Verify actual Flutter/Dart version relationship:
   - Check Flutter release notes
   - Confirm which Flutter version includes Dart 3.10+
   - Update `docs/powersync-reintegration-plan.md` with accurate info
3. ⬜ Monitor Flutter release channels:
   - Check Flutter beta channel for Dart 3.10+
   - Check Flutter dev channel
4. ⬜ Contact PowerSync community/support for clarification

**Timeline:** 1 day

---

### Phase 2: Preparation (v0.3.178+)

**Goal:** Ready the codebase for sync re-enablement

**Tasks:**
1. ⬜ Review all sync-related code for potential API changes
2. ⬜ Update documentation with accurate version requirements
3. ⬜ Prepare test plan for sync restoration:
   - Unit tests (existing 70+ tests)
   - Integration tests
   - Multi-device sync scenarios
   - Conflict resolution tests
4. ⬜ Create sync feature branch for testing
5. ⬜ Set up test sync server instance

**Timeline:** 2-3 days

---

### Phase 3: Implementation (v0.3.180+)

**Goal:** Re-enable sync functionality

**Decision Point:**
- If Flutter with Dart 3.10+ is available → Option A
- If not available → Option B (PowerSync downgrade)

**Option A Path (Preferred):**
1. ⬜ Upgrade Flutter to version with Dart 3.10+
2. ⬜ Update SDK constraints in all pubspec.yaml files
3. ⬜ Fix any breaking changes from upgrade
4. ⬜ Re-enable sync package dependency
5. ⬜ Uncomment sync routes and imports
6. ⬜ Update PowerSync API calls if needed
7. ⬜ Implement complete status mapping
8. ⬜ Run comprehensive test suite
9. ⬜ Manual testing on multiple devices
10. ⬜ Update user documentation

**Option B Path (Fallback):**
1. ⬜ Find compatible PowerSync version
2. ⬜ Downgrade PowerSync in packages/sync/pubspec.yaml
3. ⬜ Test with current Flutter 3.32.0
4. ⬜ Re-enable sync package dependency
5. ⬜ Uncomment sync routes and imports
6. ⬜ Run test suite
7. ⬜ Manual testing
8. ⬜ Document limitations

**Timeline:** 3-5 days

---

### Phase 4: Verification (v0.3.185+)

**Goal:** Ensure sync works correctly

**Tasks:**
1. ⬜ Multi-device sync testing (Android ↔ iOS ↔ Web ↔ Desktop)
2. ⬜ Offline mode testing
3. ⬜ Conflict resolution testing
4. ⬜ Performance testing (large datasets)
5. ⬜ Security testing (encryption verification)
6. ⬜ User acceptance testing

**Timeline:** 3-5 days

---

## Files Requiring Changes

### When Re-enabling Sync

#### 1. `apps/mobile/pubspec.yaml`
```yaml
# Already enabled (line 71-72), verify it stays:
sync:
  path: ../../packages/sync
```

#### 2. `apps/mobile/lib/core/router/app_router.dart`
```dart
// Uncomment imports (lines 8-11):
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
GoRoute(
  path: '/sync/login',
  name: 'sync-login',
  builder: (context, state) => const SyncLoginPage(),
),
GoRoute(
  path: '/sync/pairing',
  name: 'sync-pairing',
  builder: (context, state) => const DevicePairingPage(),
),
GoRoute(
  path: '/sync/offline-queue',
  name: 'sync-offline-queue',
  builder: (context, state) => const OfflineQueuePage(),
),
```

#### 3. `apps/mobile/lib/core/presentation/pages/main_shell.dart`
```dart
// Uncomment import:
import '../../features/sync/presentation/widgets/sync_status_indicator.dart';

// Add sync status indicator to AppBar if needed
```

#### 4. `apps/mobile/lib/features/settings/presentation/pages/settings_page.dart`
```dart
// Uncomment sync settings tile:
ListTile(
  leading: const Icon(Icons.sync),
  title: const Text('同步设置'),
  subtitle: const Text('多设备同步配置'),
  onTap: () => context.go('/settings/sync'),
),
```

#### 5. `packages/sync/lib/src/sync_client.dart`
```dart
// Fix deprecated API usage if needed (line 187-190):
// OLD (potentially deprecated):
await _powerSyncDb.connect(
  connector: _connector,
  crudThrottle: Duration(seconds: config.syncIntervalSeconds),
);

// NEW (if API changed in PowerSync):
await _powerSyncDb.connect(
  connector: _connector,
  options: SyncOptions(
    crudThrottle: Duration(seconds: config.syncIntervalSeconds),
  ),
);

// Complete status mapping (line 307-311):
void _onPowerSyncStatus(SyncStatus status) {
  _log.fine('PowerSync status: $status');
  
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

#### 6. All `pubspec.yaml` files in workspace
```yaml
# Update SDK constraint if upgrading to Dart 3.10+:
environment:
  sdk: '>=3.10.0 <4.0.0'
```

---

## Testing Checklist

When sync is re-enabled, verify:

### Unit Tests
- [ ] SyncClient initialization
- [ ] SyncEncryption key derivation
- [ ] Conflict resolution rules (all scenarios)
- [ ] Backend connector authentication
- [ ] CRUD operation handling
- [ ] Error handling and recovery

### Integration Tests
- [ ] User registration and login
- [ ] Device registration
- [ ] Initial sync (empty → populated)
- [ ] Incremental sync (changes)
- [ ] Offline mode and queue
- [ ] Online sync after offline period
- [ ] Multiple devices syncing simultaneously

### Conflict Resolution Tests
- [ ] Same field updated on different devices
- [ ] Delete vs. update conflict
- [ ] Reconciled transaction conflict
- [ ] Amount change conflict
- [ ] Timestamp-based resolution
- [ ] Field-level merge

### Multi-Device Tests
- [ ] Android ↔ Android sync
- [ ] Android ↔ iOS sync
- [ ] Mobile ↔ Web sync
- [ ] Mobile ↔ Desktop sync
- [ ] Three+ device sync simultaneously

### Performance Tests
- [ ] Sync 1000+ transactions
- [ ] Sync with large attachments
- [ ] Sync over slow network
- [ ] Sync with network interruptions
- [ ] Memory usage during sync

### Security Tests
- [ ] Encryption verification (data encrypted in transit)
- [ ] Token expiration and refresh
- [ ] Device authentication
- [ ] SQL injection prevention
- [ ] Unauthorized access prevention

---

## Monitoring & Observability

After sync restoration, monitor:

### Metrics to Track
1. **Sync Success Rate**
   - Successful syncs / total sync attempts
   - Target: > 99%

2. **Sync Latency**
   - Time from change to sync completion
   - Target: < 5 seconds for small changes

3. **Conflict Rate**
   - Conflicts encountered / total syncs
   - Target: < 1%

4. **Offline Queue Size**
   - Average pending operations
   - Target: < 100 for normal usage

5. **Error Rate**
   - Sync errors / total operations
   - Target: < 0.1%

### Logging
- Sync start/complete/duration
- Conflicts detected and resolution
- Authentication events
- Network errors
- Performance metrics

### Alerts
- Sync failure rate > 1%
- Conflict rate > 5%
- Sync latency > 30 seconds
- Authentication failures
- Server connectivity issues

---

## User Documentation Needed

When sync is re-enabled, create/update:

1. **Setup Guide**
   - Server deployment (Docker Compose)
   - Client configuration
   - Account registration
   - Device pairing

2. **User Guide**
   - How sync works
   - Offline behavior
   - Conflict resolution explanation
   - Device management

3. **Troubleshooting Guide**
   - Common issues and solutions
   - Sync status indicators
   - Manual sync trigger
   - Reset sync

4. **Privacy & Security**
   - End-to-end encryption explanation
   - Data storage locations
   - What data is synced
   - Self-hosting benefits

---

## Timeline Summary

| Phase | Version | Duration | Tasks |
|-------|---------|----------|-------|
| Clarification | v0.3.177+ | 1 day | Version research, documentation |
| Preparation | v0.3.178+ | 2-3 days | Code review, test planning |
| Implementation | v0.3.180+ | 3-5 days | Actual re-enablement |
| Verification | v0.3.185+ | 3-5 days | Testing and validation |
| **Total** | | **9-14 days** | |

**Target Release:** v0.3.190+ with fully restored sync functionality

---

## Dependencies

### Internal Dependencies
- ✅ Sync server (`apps/sync-server/`) - Ready
- ✅ Sync package (`packages/sync/`) - Implemented, disabled
- ✅ Encryption package (`packages/encryption/`) - Ready
- ✅ Database package (`packages/database/`) - Ready with sync fields

### External Dependencies
- ⚠️ Flutter with Dart 3.10+ (or PowerSync downgrade)
- ✅ PowerSync SDK (version TBD)
- ✅ PostgreSQL (for sync server)
- ✅ Docker (for server deployment)

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Flutter upgrade breaks other features | Medium | High | Comprehensive testing, feature branch |
| PowerSync API breaking changes | Low | Medium | API migration guide, testing |
| Sync performance issues | Low | Medium | Performance testing, optimization |
| Security vulnerabilities | Low | High | Security audit, encryption testing |
| User confusion with sync UI | Low | Low | Clear documentation, status indicators |
| Conflict resolution edge cases | Medium | Medium | Thorough testing, user control |

---

## Success Criteria

Sync restoration is complete when:

1. ✅ All unit tests pass (70+ existing tests)
2. ✅ Integration tests pass
3. ✅ Multi-device sync works (tested on 3+ devices)
4. ✅ Conflict resolution works correctly
5. ✅ Offline mode works and syncs when back online
6. ✅ Performance acceptable (< 5s sync latency for normal use)
7. ✅ Security verified (encryption, authentication)
8. ✅ Documentation complete and accurate
9. ✅ User acceptance testing passed
10. ✅ No critical bugs reported in 1 week of beta testing

---

## References

### Internal Documentation
- [PowerSync Re-integration Plan](./powersync-reintegration-plan.md) - Previous investigation
- [Sync Investigation v0.3.51](./sync-investigation-v0.3.51.md) - Detailed API analysis
- [Sync Architecture](./SYNC_ARCHITECTURE.md) - System design
- [CHANGELOG.md](../CHANGELOG.md) - v0.3.2 entry (when sync was disabled)
- [README.md](../README.md) - Feature overview

### External Resources
- [PowerSync Documentation](https://docs.powersync.com/)
- [PowerSync Flutter SDK](https://docs.powersync.com/client-sdks/reference/flutter)
- [PowerSync Backend Connector](https://docs.powersync.com/intro/setup-guide)
- [Flutter Release Notes](https://docs.flutter.dev/release/release-notes)
- [Dart SDK Changelog](https://github.com/dart-lang/sdk/blob/main/CHANGELOG.md)

---

## Appendix: Flutter/Dart Version Research Needed

### Questions to Answer

1. **Which Flutter version includes Dart 3.10+?**
   - Check Flutter beta channel releases
   - Check Flutter dev channel releases
   - Check Flutter roadmap

2. **What is the actual Flutter 3.32.0 Dart version?**
   - Verify against official Flutter release notes
   - There may be confusion in documentation

3. **Is there a Flutter version available now with Dart 3.10+?**
   - If yes, proceed with Option A immediately
   - If no, monitor Flutter releases

4. **PowerSync version compatibility matrix**
   - Which PowerSync versions work with Dart 3.6.0?
   - What features are in each version?

---

*Document Version: 1.0*  
*Created: 2026-05-29*  
*Last Updated: 2026-05-29*  
*Status: Investigation complete, awaiting version clarification and implementation*
