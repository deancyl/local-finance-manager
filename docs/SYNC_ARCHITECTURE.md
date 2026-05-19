# Sync System Architecture

## Overview

The sync system enables multi-device data synchronization with end-to-end encryption (E2E), ensuring maximum privacy for financial data.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Mobile App (Flutter)                        │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────┐  │
│  │ SyncClient  │───▶│ PowerSync   │───▶│ LocalFinanceDatabase    │  │
│  │             │    │ Database    │    │ (Drift + SQLite)        │  │
│  └─────────────┘    └─────────────┘    └─────────────────────────┘  │
│         │                   │                                        │
│         │                   │                                        │
│  ┌─────────────┐    ┌─────────────┐                                  │
│  │ SyncEncrypt │    │ Conflict    │                                  │
│  │ (PBKDF2)    │    │ Resolver    │                                  │
│  └─────────────┘    └─────────────┘                                  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS (JWT Auth)
                              │
┌─────────────────────────────────────────────────────────────────────┐
│                        Sync Server (Dart Frog)                       │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────┐  │
│  │ Auth        │───▶│ Sync        │───▶│ PostgreSQL              │  │
│  │ Service     │    │ Service     │    │ Database                │  │
│  │ (JWT)       │    │             │    │                         │  │
│  └─────────────┘    └─────────────┘    └─────────────────────────┘  │
│         │                   │                                        │
│         │                   │                                        │
│  ┌─────────────┐    ┌─────────────┐                                  │
│  │ Device      │    │ Conflict    │                                  │
│  │ Service     │    │ Detection   │                                  │
│  └─────────────┘    └─────────────┘                                  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ PowerSync Protocol
                              │
┌─────────────────────────────────────────────────────────────────────┐
│                      PowerSync Service (Docker)                      │
├─────────────────────────────────────────────────────────────────────┤
│  - Sync protocol handling                                            │
│  - Stream management                                                  │
│  - Conflict resolution (last-write-wins per field)                   │
└─────────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Sync Client (`packages/sync/`)

#### SyncClient
Main entry point for sync functionality.

```dart
final syncClient = SyncClient(
  config: SyncConfig(
    serverUrl: 'https://sync.example.com',
    authProvider: myAuthProvider,
  ),
  encryption: SyncEncryption.withPassword('user-password'),
);

await syncClient.initialize();
await syncClient.connect();
await syncClient.sync();
```

#### SyncConfig
Configuration and credential management.

```dart
class SyncConfig {
  final String serverUrl;
  final String databaseName;
  final Schema schema;
  final AuthProvider authProvider;
  final String? deviceId;
  final int syncIntervalSeconds;
}
```

#### SyncEncryption
Password-derived encryption keys.

```dart
class SyncEncryption {
  // PBKDF2: 100,000 iterations, 32-byte output
  Future<void> initializeWithPassword(String password);
  String encryptRecord(Map<String, dynamic> record);
  Map<String, dynamic> decryptRecord(String ciphertext);
}
```

#### FinanceAppConnector
PowerSync backend connector.

```dart
class FinanceAppConnector extends PowerSyncBackendConnector {
  Future<PowerSyncCredentials?> fetchCredentials();
  void invalidateCredentials();
  Future<void> uploadData(PowerSyncDatabase database);
}
```

#### FinanceConflictResolver
Finance-specific conflict resolution.

```dart
class FinanceConflictResolver {
  // Business rules:
  // 1. Delete conflicts → delete wins
  // 2. Reconciled transactions → manual
  // 3. Amount changes → manual
  // 4. Timestamp-based → newer wins
  // 5. Default → merge fields
  
  Future<ConflictResolution> resolve(Conflict conflict);
}
```

### 2. Sync Server (`apps/sync-server/`)

#### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/api/v1/auth/register` | POST | User registration |
| `/api/v1/auth/login` | POST | JWT token issuance |
| `/api/v1/sync/upload` | POST | Upload sync records |
| `/api/v1/sync/download` | GET | Download sync records |
| `/api/v1/sync/conflicts` | GET | List conflicts |
| `/api/v1/sync/conflicts/{id}/resolve` | POST | Resolve conflict |
| `/api/v1/devices` | GET | List devices |
| `/api/v1/devices/register` | POST | Register device |
| `/api/v1/devices/{id}` | DELETE | Delete device |

#### Services

**AuthService**: JWT authentication with PostgreSQL user storage.

**SyncService**: Upload/download with conflict detection.

**DeviceService**: Device registration and management.

**EncryptionService**: AES-256-GCM for server-side operations (optional).

### 3. Database Schema

#### PostgreSQL Tables

```sql
-- Users
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    encrypted_key TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Devices
CREATE TABLE devices (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    name TEXT NOT NULL,
    public_key TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_sync_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Sync Records
CREATE TABLE sync_records (
    id TEXT PRIMARY KEY,
    device_id TEXT NOT NULL REFERENCES devices(id),
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    operation TEXT NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    data TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    synced_at TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1,
    UNIQUE(table_name, record_id)
);

-- Conflicts
CREATE TABLE conflicts (
    id TEXT PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    device_id_1 TEXT NOT NULL REFERENCES devices(id),
    device_id_2 TEXT NOT NULL REFERENCES devices(id),
    data_1 TEXT NOT NULL,
    data_2 TEXT NOT NULL,
    resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolution TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMP
);
```

#### Drift Tables (Sync Fields Added)

All tables now have sync fields:
- `version` - Increment on each update
- `updatedAt` - Last modification timestamp
- `deletedAt` - Soft delete timestamp (nullable)

## Sync Flow

### 1. Initial Setup

```
User → Mobile App → Sync Settings
       ↓
       Enter server URL
       ↓
       Register/Login
       ↓
       Device registered
       ↓
       Encryption key derived from password
       ↓
       SyncClient initialized
```

### 2. Upload Flow

```
Local Change → Drift Database
              ↓
              PowerSync CRUD Queue
              ↓
              FinanceAppConnector.uploadData()
              ↓
              POST /api/v1/sync/upload (encrypted)
              ↓
              SyncService.upload()
              ↓
              Conflict detection
              ↓
              PostgreSQL storage
              ↓
              PowerSync stream update
```

### 3. Download Flow

```
PowerSync Connection → Stream subscription
                      ↓
                      Receive changes
                      ↓
                      Decrypt (if E2E enabled)
                      ↓
                      Apply to Drift database
                      ↓
                      UI update (Riverpod stream)
```

### 4. Conflict Resolution Flow

```
Concurrent edits → Conflict detected
                  ↓
                  FinanceConflictResolver.resolve()
                  ↓
                  Business rule evaluation:
                  - Is delete conflict? → Delete wins
                  - Is reconciled? → Manual required
                  - Has amount change? → Manual required
                  - Timestamp comparison → Newer wins
                  - Default → Merge fields
                  ↓
                  Resolution applied
                  ↓
                  If manual → UI prompt
```

## Security Model

### Encryption Layers

1. **Local Storage**: SQLCipher database encryption
2. **Sync Transport**: HTTPS + JWT authentication
3. **E2E Encryption**: PBKDF2-derived keys for sync payload

### Key Management

```
User Password → PBKDF2 (100k iterations)
               ↓
               32-byte encryption key
               ↓
               Stored in platform keychain:
               - iOS: Keychain
               - Android: Keystore
               - Web: Crypto API + IndexedDB
```

### Server Blindness

For true E2E encryption:
- Server stores encrypted data only
- Server cannot decrypt user data
- Encryption keys never sent to server
- Device public keys for verification only

## Deployment

### Docker Compose

```yaml
services:
  powersync:
    image: journeyapps/powersync-service:latest
    ports: ["8080:8080"]
    
  postgres:
    image: postgres:15-alpine
    ports: ["5432:5432"]
    
  api:
    build: .
    ports: ["3000:3000"]
```

### Environment Variables

```bash
DATABASE_HOST=postgres
DATABASE_PORT=5432
DATABASE_NAME=finance_sync
DATABASE_USER=postgres
DATABASE_PASSWORD=your_password
JWT_SECRET=your_jwt_secret
POWERSYNC_ENDPOINT=http://powersync:8080
```

## Testing

### Unit Tests

- `packages/sync/test/` - Sync client tests
- `apps/sync-server/test/` - Server tests (70+ tests)

### Integration Tests

1. Register → Login → Get Token
2. Register device → List devices
3. Upload records → Download records
4. Concurrent upload → Conflict detection
5. Resolve conflict → Verify resolution

### Manual QA

1. Two devices, same account
2. Create transaction on device A
3. Sync → Verify appears on device B
4. Edit same transaction on both devices
5. Sync → Verify conflict handling

## Troubleshooting

### Common Issues

**Sync not working**:
- Check server URL is correct
- Verify JWT token is valid
- Check network connectivity
- Review server logs

**Conflict not resolving**:
- Check conflict resolution rules
- Verify user has permission
- Review conflict data

**Encryption errors**:
- Verify password is correct
- Check keychain access
- Review encryption service logs

## Future Enhancements

### v0.3.1 - WebSocket Notifications
- Real-time sync notifications
- Push triggers for pull sync

### v0.3.2 - QR Code Pairing
- Visual device pairing
- Simplified key exchange

### v0.3.3 - Sync Status UI
- AppBar sync indicator
- Offline queue visualization
- Sync progress details

## References

- [PowerSync Documentation](https://docs.powersync.com/)
- [Dart Frog Documentation](https://dartfrog.dev/)
- [Drift Documentation](https://drift.simonbinder.eu/)