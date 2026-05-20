# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.3.3] - 2026-05-20

### Added
- **Category support in transactions**: Added `categoryId` field to Splits table for category-based reporting and budget tracking
- **Category selection in transaction dialog**: Users can now select a category when creating transactions
- **All 5 account types exposed**: Account creation dialog now shows all account types (Asset, Liability, Equity, Income, Expense)

### Fixed
- **Report calculation bug**: Replaced placeholder data with real split-based income/expense calculation
  - Reports now correctly calculate totals based on account types (INCOME/EXPENSE)
  - Uses actual transaction splits instead of hardcoded values

### Changed
- Database schema version upgraded to 3 with migration for `categoryId` column in Splits table
- Added `allSplitsWithAccountsProvider` for efficient report calculations

### Technical Details
- `packages/database/lib/src/tables/transactions.dart`: Added categoryId to Splits table
- `packages/database/lib/src/database.dart`: Schema version 3, migration logic for categoryId
- `apps/mobile/lib/features/reports/presentation/pages/reports_page.dart`: Real calculation logic
- `apps/mobile/lib/features/transactions/data/transaction_provider.dart`: New provider, categoryId support
- `apps/mobile/lib/features/transactions/presentation/widgets/add_transaction_dialog.dart`: Category dropdown
- `apps/mobile/lib/features/accounts/presentation/widgets/add_account_dialog.dart`: All 5 account types

## [v0.3.2] - 2026-05-20

### Changed
- **Sync feature temporarily disabled** due to PowerSync API compatibility issues
  - PowerSync package requires Dart SDK >=3.10.0 but Flutter 3.27.1 uses Dart 3.6.0
  - Sync UI components and routes removed from mobile app
  - Sync server code remains in repository for future development

### Fixed
- Added missing `dart:math` import for `Random` in encryption services
- Added missing `updatedAt` field to default categories in database
- Fixed dependency version constraints for `dart_jsonwebtoken`, `postgres`, `dart_frog_test`

### Technical Details
- `apps/mobile/pubspec.yaml`: Disabled sync package dependency
- `apps/mobile/lib/core/router/app_router.dart`: Removed sync routes
- `apps/mobile/lib/core/presentation/pages/main_shell.dart`: Removed sync status indicator
- `apps/mobile/lib/features/settings/presentation/pages/settings_page.dart`: Removed sync settings
- `packages/encryption/lib/src/crypto/encryption_service.dart`: Added dart:math import
- `packages/sync/lib/src/encryption/encryption_service.dart`: Added dart:math import
- `packages/database/lib/src/database.dart`: Added updatedAt to default categories

### Build Artifacts
- Android APK (debug): `app-debug.apk`
- Web build: `finance-app-web.zip`
- Windows build: `finance-app-windows-debug.zip`

## [v0.3.0] - 2026-05-19

### Added - Phase 3: Sync System

#### Sync Server (Dart Frog + PostgreSQL)
- REST API with JWT authentication (7-day tokens)
- Endpoints:
  - `POST /api/v1/auth/register` - User registration
  - `POST /api/v1/auth/login` - JWT token issuance
  - `POST /api/v1/sync/upload` - Upload encrypted records
  - `GET /api/v1/sync/download` - Download since timestamp
  - `GET /api/v1/sync/conflicts` - List conflicts
  - `POST /api/v1/sync/conflicts/{id}/resolve` - Resolve conflict
  - `GET /api/v1/devices` - List devices
  - `POST /api/v1/devices/register` - Register device
  - `DELETE /api/v1/devices/{id}` - Delete device
- PostgreSQL schema with proper indexes
- Docker Compose configuration (PowerSync + PostgreSQL + API)
- AES-256-GCM encryption (replaced XOR placeholder)

#### Flutter Sync Package
- `SyncClient` - PowerSync database wrapper with Drift integration
- `SyncConfig` - Server URL, credentials, device ID management
- `SyncEncryption` - Password-derived encryption keys (PBKDF2, 100k iterations)
- `FinanceAppConnector` - PowerSyncBackendConnector implementation
- `FinanceConflictResolver` - Finance-specific conflict resolution:
  - Delete conflicts: delete wins
  - Reconciled transactions: manual resolution required
  - Amount changes: manual resolution required
  - Timestamp-based: newer wins
  - Default: field merge

#### Database Schema Updates
- Added sync fields to 4 tables:
  - `categories`: version, updatedAt, deletedAt
  - `budgets`: version, updatedAt, deletedAt
  - `import_sources`: version, updatedAt
  - `import_batches`: version, updatedAt
- Schema version bumped to 2
- Migration logic for existing databases

#### PowerSync Configuration
- Fixed `powersync.yaml` with correct column names
- 8 tables configured with user_id filtering:
  - accounts, transactions, splits, categories, budgets
  - import_sources, import_batches, commodities
- `user_data` stream for user-owned data
- `shared_data` stream for reference data (commodities)

#### Mobile App Integration
- `features/sync/` directory with Riverpod providers
- Sync settings page with:
  - Server URL configuration
  - Login/Register forms
  - Sync status indicator
  - Device list with last sync time
  - Manual sync button
- Auth provider implementation with secure storage
- Navigation from settings to sync configuration

### Security Improvements
- **CRITICAL**: Replaced XOR encryption placeholder with AES-256-GCM
- Server encryption now uses `packages/encryption`
- E2E encryption architecture for sync data
- Password-derived keys with PBKDF2 (100k iterations, 32-byte output)

### Technical Details

**New Dependencies:**
- powersync: ^1.9.0 (Sync protocol)
- drift_sqlite_async: ^0.3.0 (Drift + PowerSync integration)
- jwt: ^2.0.0 (JWT token handling)
- postgres: ^3.5.5 (PostgreSQL client)

**Sync Package Structure:**
```
packages/sync/
├── lib/
│   ├── sync.dart                    # Main export
│   └── src/
│       ├── sync_client.dart         # PowerSync wrapper
│       ├── sync_config.dart         # Configuration + AuthProvider
│       ├── encryption/
│       │   └── encryption_service.dart  # PBKDF2 key derivation
│       ├── conflict/
│       │   └── conflict_resolver.dart   # Finance-specific rules
│       ├── connector/
│       │   └── backend_connector.dart   # PowerSync connector
│       └── models/
│           └── sync_models.dart     # SyncCredentials, SyncDevice
└── test/                            # Unit tests
```

**Sync Server Structure:**
```
apps/sync-server/
├── server.dart                      # Dart Frog entry point
├── src/
│   ├── services/
│   │   ├── auth_service.dart        # JWT authentication
│   │   ├── sync_service.dart        # Upload/download/conflict
│   │   ├── device_service.dart      # Device management
│   │   └── encryption_service.dart  # AES-256-GCM
│   ├── middleware/
│   │   └── auth_middleware.dart     # JWT validation
│   ├── models/
│   │   └── sync_models.dart         # SyncRecord, Device, User
│   └── database/
│       └── connection.dart          # PostgreSQL connection
├── database/
│   └── schema.sql                   # Database schema
├── powersync.yaml                   # PowerSync stream config
├── docker-compose.yml               # Docker orchestration
└── test/                            # 70+ unit tests
```

### Next Steps - v0.3.x

Planned improvements:
- WebSocket real-time sync notifications
- QR code device pairing
- Sync status indicator in app bar
- Offline queue visualization
- Multi-device sync testing
- Performance optimization

## [v0.2.0] - 2026-05-19

### Added - Phase 2: Import System

#### Import Pipeline Architecture
- `ImporterBase` abstract class for all financial institution importers
- `ImportResult` and `ImportStats` models for parse results
- `ImportConfig` for customizable import settings
- `ImportPreview` for pre-import verification

#### Utility Classes
- `CsvParser` - CSV parsing with encoding detection
- `EncodingDetector` - Auto-detect GBK/UTF-8/UTF-16 encodings
- `DateParser` - Parse Chinese date formats (2026年5月19日, 今天, 昨天, etc.)
- `AmountParser` - Parse Chinese amount formats (¥1.23万, +¥100, (100))
- `DuplicateDetector` - Detect duplicate transactions by external ID or fuzzy match

#### Alipay Importer
- Parse Alipay CSV export files
- Support for 余额, 余额宝, 花呗, 银行卡 accounts
- Category mapping for 30+ Alipay categories
- Transaction type detection (收入/支出)
- External ID extraction from transaction order numbers

#### WeChat Pay Importer
- Parse WeChat Pay CSV export files
- Handle backtick prefix (common in WeChat exports)
- Support for 零钱, 零钱通, 银行卡 accounts
- Category mapping for WeChat transaction types
- Red packet (红包) and transfer (转账) support

#### Bank Importers
- **ICBC (工商银行)** - GBK/UTF-8 encoding, standard bank format
- **CCB (建设银行)** - Separate income/expense columns
- **BOC (中国银行)** - Debit/credit columns, reference numbers

#### Import UI
- Import page with file picker
- Preview table for parsed transactions
- Source detection display
- Import statistics summary

### Documentation
- `PRIVACY_POLICY.md` - Privacy policy for app store submission (English/Chinese)

### Technical Details

**New Dependencies:**
- csv: ^6.0.0 (CSV parsing)
- file_picker: ^8.1.4 (File selection)

**Importers Package Structure:**
```
packages/importers/
├── lib/
│   ├── importers.dart          # Main export file
│   └── src/
│       ├── base/               # Base classes
│       │   ├── importer_base.dart
│       │   ├── import_result.dart
│       │   └── import_config.dart
│       ├── utils/              # Utility classes
│       │   ├── csv_parser.dart
│       │   ├── encoding_detector.dart
│       │   ├── date_parser.dart
│       │   ├── amount_parser.dart
│       │   └── duplicate_detector.dart
│       ├── alipay/             # Alipay importer
│       ├── wechat/             # WeChat Pay importer
│       └── banks/              # Bank importers
│           ├── icbc_importer.dart
│           ├── ccb_importer.dart
│           └── boc_importer.dart
└── test/                       # Unit tests
```

## [v0.1.0] - 2026-05-19

### Added - Phase 1: Foundation

#### Project Setup
- Monorepo structure with melos for multi-package management
- Git repository initialized with proper .gitignore
- GitHub repository created at https://github.com/deancyl/local-finance-manager
- Cross-platform Flutter project (iOS, Android, Web, Windows, macOS, Linux)

#### Database Layer
- Drift (SQLite ORM) database implementation
- 8 table definitions:
  - `commodities` - Currencies, stocks, crypto
  - `accounts` - Chart of accounts with hierarchy
  - `transactions` - Journal entry headers
  - `splits` - Individual debit/credit entries
  - `categories` - Transaction categorization
  - `budgets` - Spending limits per category
  - `import_sources` - Financial institutions
  - `import_batches` - Import operation tracking
- 5 Data Access Objects (DAOs) with CRUD operations
- Default commodities (CNY, USD) and categories seeded

#### Core Models
- Domain models with Equatable for value comparison:
  - `Account` - Financial account with type hierarchy
  - `Transaction` - Journal entry with splits
  - `Split` - Debit/credit entry with reconciliation
  - `Category` - Transaction categorization
  - `Commodity` - Currency/stock/crypto
  - `Budget` - Spending limit with period
  - `ImportSource` - Financial institution
  - `ImportBatch` - Import operation result
- Repository interfaces for data access abstraction
- Use cases for business logic:
  - `AddTransaction` - Single/double entry creation
  - `GetBalance` - Account balance calculation
  - `ImportTransactions` - Bulk import with deduplication

#### Encryption Layer
- `KeychainService` interface for secure key storage
- Platform-specific implementations:
  - `MobileKeychainService` - iOS Keychain / Android Keystore
  - `WebKeychainService` - Web Crypto API + IndexedDB
- `EncryptionService` with AES-256-GCM encryption
- PBKDF2 key derivation (100,000 iterations)

#### UI Shell
- Material 3 design system with light/dark themes
- GoRouter navigation with bottom navigation bar
- 6 main pages:
  - Home - Net worth overview, quick actions
  - Transactions - Transaction list with date grouping
  - Accounts - Account management by type
  - Budgets - Budget tracking (placeholder)
  - Reports - Income/expense summary
  - Settings - App configuration

#### Feature Implementation
- Account management CRUD with Riverpod state management
- Transaction management with income/expense toggle
- Category management with expense/income separation
- Basic reports with income/expense/balance summary

### Technical Details

**Dependencies:**
- Flutter 3.24.5 / Dart 3.5.4
- drift: ^2.22.1 (SQLite ORM)
- flutter_riverpod: ^2.6.1 (State management)
- go_router: ^14.6.2 (Navigation)
- flutter_secure_storage: ^9.2.2 (Keychain)
- pointycastle: ^3.9.1 (Encryption)
- uuid: ^4.5.1 (ID generation)

**Project Structure:**
```
finance-app/
├── apps/
│   ├── mobile/           # Flutter mobile application
│   ├── desktop/          # Flutter desktop application (planned)
│   └── sync-server/      # Sync server (Phase 3)
├── packages/
│   ├── core/             # Domain models, repositories, use cases
│   ├── database/         # Drift database layer
│   ├── encryption/       # Encryption and keychain
│   ├── importers/        # Financial institution importers (Phase 2)
│   ├── sync/             # Sync client package (Phase 3)
│   └── ai/               # Local AI integration (Phase 5)
└── docs/                 # Documentation
```