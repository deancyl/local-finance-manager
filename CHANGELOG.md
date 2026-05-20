# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.3.16] - 2026-05-21

### Added
- **Dark Mode**: Full dark theme support with system/light/dark options
  - Material 3 dark theme with proper color scheme
  - Theme persistence via SharedPreferences
  - Theme settings page with radio selection
  - System theme mode follows device settings automatically

### Technical Details
- `apps/mobile/lib/core/theme/app_theme.dart` - Light and dark ThemeData definitions
- `apps/mobile/lib/features/settings/data/theme_provider.dart` - ThemeNotifier with persistence
- `apps/mobile/lib/features/settings/presentation/pages/theme_settings_page.dart` - Theme selection UI

## [v0.3.15] - 2026-05-20

### Added
- **Pagination**: Infinite scroll for transactions list
  - PAGE_SIZE = 20 transactions per page
  - Load more on scroll to bottom
  - Pull-to-refresh resets pagination
- **Database-Level Filtering**: Efficient SQL filtering for transactions
  - Date range filtering at database level
  - Category and account filtering
  - Text search in description and notes
- **Chart Interactions**: Click charts to drill down
  - Bar chart click navigates to filtered transactions
  - Pie chart click shows category transactions

### Fixed
- `distinct()` not supported in Drift selectOnly - changed to GROUP BY
- fl_chart API: use `spot.x.toInt()` instead of `tappedBarGroup`

### Technical Details
- `packages/database/lib/src/daos/transactions_dao.dart` - `getTransactionsPaginated`, `getFilteredTransactionsPaginated`
- `apps/mobile/lib/features/transactions/data/transaction_provider.dart` - PaginationState, PaginatedTransactionsNotifier
- `apps/mobile/lib/features/reports/presentation/widgets/monthly_trend_chart.dart` - Chart touch callback

## [v0.3.14] - 2026-05-20

### Fixed
- Split import conflict with Flutter's Split widget
- Value<String?> type handling for nullable fields

## [v0.3.13] - 2026-05-20

### Added
- Account balance calculation fix
- GBK encoding support for Chinese bank imports
- Transfer transaction support
- Bank statement importers (ICBC, CCB, BOC)
- Database Schema v5 with Tags, Attachments, RecurringTransactions tables

## [v0.3.12] - 2026-05-20

### Added
- Data backup settings page
- Export/import functionality

## [v0.3.11] - 2026-05-20

### Added
- Language settings (zh_CN, zh_TW, en_US)
- Locale persistence via SharedPreferences

## [v0.3.10] - 2026-05-20

### Added
- Theme settings page foundation

## [v0.3.9] - 2026-05-20

### Added
- **Transaction Search/Filter**: Full search and filter functionality for transactions
  - Search by description and notes (text search)
  - Filter by date range (start/end date pickers)
  - Filter by category (dropdown with "全部" option)
  - Filter by account (dropdown with "全部" option)
  - Filter by amount range (min/max absolute value)
  - Combined filters (all filters can be applied together)
  - Clear filters button
  - Filter indicator badge on filter button when filters active
  - Empty state for no results with clear filters option

### Changed
- **TransactionsPage enhanced**: Connected filter button to filter dialog
  - Uses filteredTransactionsWithSplitsProvider for filtered results
  - Shows badge indicator when filters are active
  - Displays "未找到符合条件的交易" when filters return no results

### Technical Details
- `apps/mobile/lib/features/transactions/data/transaction_filter.dart` - Immutable filter state class with copyWith
- `apps/mobile/lib/features/transactions/data/transaction_provider.dart` - Filter providers (transactionFilterProvider, filteredTransactionsProvider, filteredTransactionsWithSplitsProvider)
- `apps/mobile/lib/features/transactions/presentation/widgets/transaction_filter_dialog.dart` - Filter UI with all filter options
- `apps/mobile/lib/features/transactions/presentation/pages/transactions_page.dart` - Filter integration

## [v0.3.8] - 2026-05-20

### Added
- **Account Hierarchy**: Full support for account grouping and tree structure
  - Account groups (placeholders) for organizing accounts
  - Parent-child relationships with unlimited depth
  - Tree view with expand/collapse for groups
  - Subtotal calculation for groups (hybrid model: own balance + children)
  - Default account groups seeded on first launch (银行账户, 现金, 投资账户, etc.)
  - Parent account selector in add/edit dialog
  - "作为账户组" toggle for creating group accounts

### Changed
- **AccountsPage refactored**: Replaced flat list with tree view
  - Uses AccountTreeCard widget with ExpansionTile
  - Shows subtotals per account type section
  - Add child button for group accounts
- **AccountNotifier enhanced**: Added validation
  - Circular reference prevention
  - Delete protection for accounts with children
- **AccountsDao extended**: Added hierarchy methods
  - getRootAccountsByType(), watchRootAccountsByType()
  - getDescendantIds(), hasChildren()

### Technical Details
- `apps/mobile/lib/features/accounts/data/account_provider.dart` - Hierarchy providers (rootAccountsProvider, childAccountsProvider, accountHierarchyProvider, AccountTreeNode)
- `apps/mobile/lib/features/accounts/presentation/widgets/account_tree_card.dart` - Tree card widget with ExpansionTile
- `apps/mobile/lib/features/accounts/presentation/widgets/add_account_dialog.dart` - Parent selector and isPlaceholder toggle
- `apps/mobile/lib/features/accounts/presentation/pages/accounts_page.dart` - Tree view integration
- `packages/database/lib/src/database.dart` - Default account groups seeder
- `packages/database/lib/src/daos/accounts_dao.dart` - Hierarchy extension methods

## [v0.3.7] - 2026-05-20

### Added
- **Report Visualizations**: Added interactive charts to reports page
  - Monthly trend bar chart showing last 6 months income/expense
  - Category breakdown pie chart showing expense distribution by category
  - Legend with color indicators for income (green) and expense (red)
  - Empty state handling when no data is available

### Changed
- **ReportsPage enhanced**: Replaced placeholder with real chart widgets
  - Uses fl_chart for visualization
  - Async loading states for chart data
  - Responsive layout with scrollable content

### Technical Details
- `apps/mobile/lib/features/reports/data/chart_providers.dart` - Monthly aggregation and category breakdown providers
- `apps/mobile/lib/features/reports/presentation/widgets/monthly_trend_chart.dart` - Bar chart widget
- `apps/mobile/lib/features/reports/presentation/widgets/category_breakdown_chart.dart` - Pie chart widget
- `apps/mobile/lib/features/reports/presentation/pages/reports_page.dart` - Integrated charts

## [v0.3.6] - 2026-05-20

### Added
- **Home Page Real Data**: Connected home dashboard to real account and transaction data
  - Net worth calculated from ASSET accounts minus LIABILITY accounts
  - Asset total shows sum of all ASSET account balances
  - Liability total shows sum of all LIABILITY account balances
  - Recent transactions list (last 10 transactions)
  - Quick stats: today's transaction count, this month's income/expense

### Changed
- **HomePage refactored**: Converted from StatelessWidget to ConsumerWidget
  - Uses Riverpod providers for reactive data
  - AsyncValue handling for loading/error states
  - Real data replaces hardcoded ¥0.00 placeholders

### Technical Details
- `packages/core/lib/src/data/repositories/account_repository_impl.dart` - AccountRepository implementation
- `apps/mobile/lib/features/home/data/home_providers.dart` - Home data providers
- `apps/mobile/lib/core/presentation/pages/home_page.dart` - Connected to real data

## [v0.3.5] - 2026-05-20

### Added
- **Import Feature Integration**: Connected import UI to existing importers package
  - Real CSV parsing for Alipay, WeChat Pay, ICBC, CCB, BOC
  - Automatic source detection based on file content
  - Preview table shows actual parsed data
  - Account selection dropdown before import
  - Duplicate detection and silent skip
  - Import result dialog with success/duplicate/error counts

### Changed
- **ImportPage refactored**: Replaced placeholder data with real importer integration
  - Uses `ImporterRegistry` for source detection
  - Calls `ImporterBase.preview()` for data preview
  - Calls `ImporterBase.parse()` for actual import
  - Uses `ImportTransactions` use case for database persistence

### Technical Details
- `apps/mobile/lib/features/import/data/importer_registry.dart` - Importer detection factory
- `apps/mobile/lib/features/import/providers/import_providers.dart` - Riverpod providers for import
- `apps/mobile/lib/features/import/presentation/pages/import_page.dart` - Connected to real importers

## [v0.3.4] - 2026-05-20

### Added
- **Budget Management UI**: Complete budget tracking feature with visual progress display
  - Budget list page with spending progress bars
  - Add/edit budget dialog with category selection
  - Budget card showing spent vs. total amount with percentage
  - Over-budget warning indicator (red bar + warning text)
  - Support for MONTHLY, YEARLY, and CUSTOM budget periods

### Changed
- **BudgetsDao extended**: Added spending calculation methods
  - `calculateSpentAmountNum()` - Query splits by categoryId + date range + EXPENSE account type
  - `watchSpentAmountNum()` - Reactive spending updates
  - `getProgress()` - Calculate budget usage percentage
- **Database schema version 4**: Added performance index for budget queries
  - Composite index on `splits(category_id, transaction_id)`
- **BudgetPeriodCalculator utility**: Calendar-based period boundary calculation
  - MONTHLY: 1st to last day of month
  - YEARLY: Jan 1 to Dec 31
  - Days remaining and total days helpers

### Technical Details
- `packages/core/lib/src/utils/budget_period_calculator.dart` - Period calculation utility
- `packages/database/lib/src/daos/budgets_dao.dart` - Extended with spending calculations
- `packages/database/lib/src/database.dart` - Schema v4, performance index
- `apps/mobile/lib/features/budgets/data/budget_provider.dart` - State management
- `apps/mobile/lib/features/budgets/presentation/widgets/budget_card.dart` - Progress card
- `apps/mobile/lib/features/budgets/presentation/widgets/add_budget_dialog.dart` - Form dialog
- `apps/mobile/lib/features/budgets/presentation/pages/budgets_page.dart` - List page

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