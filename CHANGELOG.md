# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
├── apps/mobile/           # Flutter mobile application
├── packages/
│   ├── core/              # Domain models, repositories, use cases
│   ├── database/          # Drift database layer
│   ├── encryption/        # Encryption and keychain
│   ├── importers/         # Financial institution importers (Phase 2)
│   └── ai/                # Local AI integration (Phase 5)
└── docs/                  # Documentation
```

### Next Steps - Phase 2: Import System

Planned features:
- Import pipeline architecture
- Alipay CSV importer
- WeChat Pay CSV importer
- ICBC/CCB/BOC bank statement importers
- Deduplication engine
- Import preview and category mapping UI