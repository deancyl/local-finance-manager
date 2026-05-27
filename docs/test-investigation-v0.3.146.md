# Test Investigation Report - v0.3.146

**Investigation Date:** 2026-05-27  
**Version Context:** v0.3.145 → v0.3.146  
**Issue:** Tests disabled in CI workflow (test.yml)

---

## Executive Summary

Tests in CI were disabled due to pre-existing test failures that require deeper investigation. The primary cause is the **PowerSync dependency being temporarily disabled** which causes test failures in the sync package tests.

**Status:** Investigation complete  
**Root Cause:** PowerSync package dependency commented out in `packages/sync/pubspec.yaml`  
**Impact:** All sync-related tests fail; other tests may have unrelated issues  

---

## Current Test Configuration

### CI Workflow (test.yml)

```yaml
# Tests disabled - pre-existing failures require deeper investigation
# - name: Run tests
#   run: melos run test
```

The test step is commented out with a clear note about pre-existing failures.

### Melos Test Configuration

```yaml
# melos.yaml
test:
  run: |
    melos exec --ignore="sync" --ignore="sync_server" --dir-exists=test -- "flutter test --coverage"
```

Note: Tests explicitly ignore `sync` and `sync_server` packages, but this configuration may not be sufficient.

---

## Root Cause Analysis

### Primary Cause: PowerSync Dependency Disabled

**File:** `packages/sync/pubspec.yaml`

```yaml
dependencies:
  # powersync: ^1.9.0  # Temporarily disabled - see sync_client.dart
```

The PowerSync package is commented out due to Dart SDK version compatibility issues (see `docs/sync-investigation-v0.3.51.md`).

**Impact:**
- Sync package tests cannot compile/run
- Tests importing sync package fail
- Import errors propagate to dependent code

### Secondary Causes

1. **Sync Tests Import Disabled Dependency**

   Multiple test files import PowerSync:
   - `packages/sync/test/sync_client_test.dart` - imports `powersync` package
   - `packages/sync/test/sync_config_test.dart` - may have PowerSync imports
   - `packages/sync/test/connector/backend_connector_test.dart` - PowerSync backend connector
   - `packages/sync/test/conflict/conflict_resolver_test.dart` - conflict resolution
   - `packages/sync/test/encryption/encryption_service_test.dart` - encryption tests

2. **Mock Dependencies**

   Tests use `mocktail` to mock `PowerSyncDatabase`:
   ```dart
   class MockPowerSyncDatabase extends Mock implements PowerSyncDatabase {}
   ```

   Without the actual package, the mock cannot be created.

---

## Test Failure Categories

### Category 1: Sync Package Tests (BLOCKING)

**Files affected:**
- `packages/sync/test/sync_client_test.dart`
- `packages/sync/test/sync_config_test.dart`
- `packages/sync/test/connector/backend_connector_test.dart`
- `packages/sync/test/conflict/conflict_resolver_test.dart`
- `packages/sync/test/encryption/encryption_service_test.dart`
- `packages/sync/test/compatibility/sync_compatibility_checker_test.dart`
- `packages/sync/test/websocket/sync_websocket_test.dart`

**Expected failure:** Import error - `package:powersync/powersync.dart` not found

**Resolution:** Skip sync tests until PowerSync re-enabled, or create stub implementations

### Category 2: Sync Server Tests

**Files affected:**
- `apps/sync-server/test/auth_service_test.dart`
- `apps/sync-server/test/device_service_test.dart`
- `apps/sync-server/test/sync_service_test.dart`
- `apps/sync-server/test/encryption_service_test.dart`

**Status:** May work independently if not importing sync package

**Resolution:** Can be run separately if no sync package dependencies

### Category 3: Mobile App Tests

**Files affected:**
- `apps/mobile/test/widget_test.dart` - Basic widget test
- `apps/mobile/test/features/sync/data/offline_queue_model_test.dart` - Sync-dependent
- `apps/mobile/test/features/sync/data/device_pairing_service_test.dart` - Sync-dependent
- `apps/mobile/test/features/transactions/presentation/pages/add_transaction_page_test.dart`
- `apps/mobile/test/core/presentation/widgets/validated_text_field_test.dart`
- `apps/mobile/test/features/transactions/journal_entry_integration_test.dart`

**Status:** Some may work, sync-related tests will fail

### Category 4: Package Tests (Likely Working)

**Files:**
- `packages/core/test/validation/validation_service_test.dart`
- `packages/core/test/usecases/trial_balance_calculator_test.dart`
- `packages/core/test/usecases/journal_entry_validator_test.dart`
- `packages/importers/test/alipay/alipay_importer_test.dart`
- `packages/importers/test/wechat/wechat_importer_test.dart`
- `packages/importers/test/banks/abc_importer_test.dart`
- `packages/importers/test/banks/cmb_importer_test.dart`
- `packages/encryption/test/encryption_test.dart`
- `packages/ai/test/ai_service_test.dart`

**Status:** Should work - no sync dependencies

---

## Recommended Fix Strategy

### Option A: Update Melos Configuration (RECOMMENDED)

Update `melos.yaml` to properly skip sync tests:

```yaml
test:
  run: |
    melos exec --ignore="sync" --ignore="sync_server" --dir-exists=test -- "flutter test --coverage"
  
test:sync:
  run: |
    melos exec --scope="sync" --dir-exists=test -- "flutter test --coverage"
  description: Run sync tests (requires PowerSync package)
```

This ensures non-sync tests run while sync tests are skipped.

### Option B: Create Test Stubs

Create stub implementations for PowerSync types to allow tests to compile:

```dart
// packages/sync/test/stubs/powersync_stub.dart
class PowerSyncDatabase {}
class Schema {}
class Table {}
class Column {}
// ... other stubs
```

This allows tests to run without actual PowerSync package.

### Option C: Fix Sync Package First

Re-enable PowerSync package (requires Flutter/Dart upgrade as per `docs/powersync-reintegration-plan.md`):

1. Upgrade to Flutter 3.29+ (Dart 3.10+)
2. Uncomment PowerSync dependency
3. Run all tests

**Estimated effort:** 2-4 days (see PowerSync re-integration plan)

---

## Immediate Actions for v0.3.147

To re-enable tests in CI:

1. **Update test.yml to run non-sync tests only:**

```yaml
- name: Run tests
  run: melos exec --ignore="sync" --ignore="sync_server" --dir-exists=test -- "flutter test --coverage"
```

2. **Update melos.yaml test script:**

```yaml
test:
  run: |
    melos exec --ignore="sync" --ignore="sync_server" --dir-exists=test -- "flutter test --coverage"
```

3. **Verify non-sync tests pass locally before committing**

---

## Test Count Summary

| Package | Test Files | Expected Status |
|---------|------------|-----------------|
| sync | 8 | ❌ Fail (PowerSync missing) |
| sync_server | 4 | ⚠️ May fail (sync dependency) |
| mobile | 6 | ⚠️ Mixed (sync tests fail) |
| core | 3 | ✅ Should pass |
| importers | 4 | ✅ Should pass |
| encryption | 1 | ✅ Should pass |
| ai | 1 | ✅ Should pass |

**Total test files:** 26  
**Expected failing:** ~14 (sync + sync_server + mobile sync tests)  
**Expected passing:** ~12 (core + importers + encryption + ai + mobile non-sync)

---

## Resolution Checklist

For v0.3.147 (Re-enable tests):

- [ ] Update `melos.yaml` to explicitly skip sync packages
- [ ] Update `test.yml` to use updated melos test command
- [ ] Verify non-sync tests pass locally
- [ ] Run CI and check test results
- [ ] Document which tests are still failing (if any)

For future (Fix sync tests):

- [ ] Upgrade Flutter to 3.29+ (Dart 3.10+)
- [ ] Re-enable PowerSync dependency
- [ ] Update sync tests for new API
- [ ] Run full test suite

---

## References

- [sync-investigation-v0.3.51.md](./sync-investigation-v0.3.51.md) - PowerSync compatibility details
- [powersync-reintegration-plan.md](./powersync-reintegration-plan.md) - Re-integration roadmap
- [CHANGELOG.md](../CHANGELOG.md) - v0.3.2 entry for sync disable

---

*Document generated: 2026-05-27*  
*Status: Investigation complete, ready for v0.3.147 implementation*