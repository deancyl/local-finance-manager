# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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