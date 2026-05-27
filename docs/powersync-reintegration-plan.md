# PowerSync Re-integration Plan

## Current Status

- **Flutter SDK**: 3.32.0 (Dart 3.6.0)
- **PowerSync Package**: Requires Dart SDK >=3.10.0
- **Sync Feature**: Temporarily disabled in v0.3.2 due to API compatibility issues

## Requirements

### Flutter SDK Upgrade Path

PowerSync requires Flutter 3.29+ which includes Dart SDK >=3.10.0.

Current Flutter 3.32.0 already meets this requirement:
- Flutter 3.32.0 includes Dart 3.6.0
- Need Flutter SDK with Dart >=3.10.0 for PowerSync compatibility

### PowerSync Package Requirements

```yaml
dependencies:
  powersync: ^1.9.0
  drift_sqlite_async: ^0.3.0
```

## Re-integration Steps

### Phase 1: Environment Validation

1. Verify Flutter SDK version with Dart >=3.10.0
2. Update `pubspec.yaml` environment constraints
3. Run `flutter pub get` with updated dependencies

### Phase 2: Sync Module Restoration

1. Re-enable sync package in `apps/mobile/pubspec.yaml`
2. Restore sync routes in `app_router.dart`
3. Restore sync status indicator in `main_shell.dart`
4. Restore sync settings in `settings_page.dart`

### Phase 3: Database Schema Updates

1. Verify sync fields in all tables (version, updatedAt, deletedAt)
2. Ensure migration logic is compatible
3. Test conflict resolution rules

### Phase 4: Testing

1. Unit tests for sync client
2. Integration tests with sync server
3. Multi-device sync validation
4. Conflict resolution testing

## API Compatibility Notes

### PowerSync API Changes

- `PowerSyncDatabase` constructor requires `schema` parameter
- `connectivity` changes in PowerSync 1.9.0
- `SyncStatus` API improvements

### Drift Integration

- `drift_sqlite_async` provides Drift + PowerSync integration
- Existing Drift schema definitions remain compatible
- DAO methods require no changes

## Code Structure

```
packages/sync/
├── lib/
│   ├── sync.dart                    # Main export
│   └── src/
│       ├── sync_client.dart         # PowerSync wrapper
│       ├── sync_config.dart         # Configuration
│       ├── encryption/
│       │   └── encryption_service.dart
│       ├── conflict/
│       │   └── conflict_resolver.dart
│       └── connector/
│           └── backend_connector.dart
```

## Timeline

| Version | Task | Status |
|---------|------|--------|
| v0.3.156 | Documentation and preparation | Done |
| v0.3.157+ | Environment validation | Pending |
| Future | Full re-integration | Pending |

## References

- [PowerSync Documentation](https://docs.powersync.com/)
- [Flutter 3.29 Release Notes](https://docs.flutter.dev/release/release-notes)
- [Sync Architecture](./SYNC_ARCHITECTURE.md)
