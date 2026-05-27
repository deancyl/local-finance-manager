# Integration Testing Plan

## Overview

This document outlines the integration testing strategy for the Local Finance Manager application.

## Test Categories

### 1. Database Integration Tests

#### Schema Migration Tests

- Test database creation from scratch
- Test schema version migrations (v1 → v2 → v3 → ... → v16)
- Verify data integrity after migrations
- Test rollback scenarios

#### DAO Integration Tests

| DAO | Test Cases | Priority |
|-----|------------|----------|
| AccountsDao | CRUD operations, hierarchy queries, balance calculations | High |
| TransactionsDao | CRUD, splits, filtering, pagination | High |
| CategoriesDao | CRUD, hierarchy, default seeding | Medium |
| BudgetsDao | CRUD, progress calculation, period boundaries | High |
| JournalEntriesDao | CRUD, balance validation, reversal | High |
| InvestmentHoldingsDao | CRUD, performance calculation | Medium |
| ExchangeRatesDao | CRUD, conversion calculation | Medium |

#### Test Files

```
packages/database/test/
├── database_test.dart              # Schema creation/migration
├── daos/
│   ├── accounts_dao_test.dart
│   ├── transactions_dao_test.dart
│   ├── categories_dao_test.dart
│   ├── budgets_dao_test.dart
│   ├── journal_entries_dao_test.dart
│   └── investment_holdings_dao_test.dart
│   └── exchange_rates_dao_test.dart
└── integration/
│   └── full_workflow_test.dart     # End-to-end database operations
```

### 2. Import Integration Tests

#### Importer Tests

| Importer | Test Cases | Priority |
|----------|------------|----------|
| AlipayImporter | CSV parsing, encoding detection, category mapping | High |
| WeChatPayImporter | CSV parsing, backtick handling, account detection | High |
| ICBCImporter | GBK encoding, bank format parsing | Medium |
| CCBImporter | Separate income/expense columns | Medium |
| BOCImporter | Debit/credit columns, reference numbers | Medium |

#### Import Pipeline Tests

- File encoding detection (GBK, UTF-8, UTF-16)
- Date parsing for various formats
- Amount parsing for Chinese formats (¥1.23万)
- Duplicate detection by external ID and fuzzy match
- Preview generation accuracy
- Import result statistics

#### Test Files

```
packages/importers/test/
├── importers_test.dart             # Package integration
├── utils/
│   ├── csv_parser_test.dart
│   ├── encoding_detector_test.dart
│   ├── date_parser_test.dart
│   ├── amount_parser_test.dart
│   └── duplicate_detector_test.dart
├── alipay/
│   └── alipay_importer_test.dart
├── wechat/
│   └── wechat_importer_test.dart
└── banks/
    ├── icbc_importer_test.dart
    ├── ccb_importer_test.dart
    └── boc_importer_test.dart
```

### 3. Sync Integration Tests

#### Sync Server Tests

- User authentication (register, login, JWT)
- Sync upload/download operations
- Conflict detection and resolution
- Device management (register, list, delete)
- Encryption/decryption workflow

#### Sync Client Tests

- PowerSync connection establishment
- Data synchronization workflow
- Offline queue management
- Conflict resolution strategies
- Encryption key derivation

#### Test Files

```
apps/sync-server/test/
├── auth_test.dart
├── sync_test.dart
├── device_test.dart
├── conflict_test.dart
└── encryption_test.dart

packages/sync/test/
├── sync_client_test.dart
├── encryption_test.dart
├── conflict_resolver_test.dart
└── connector_test.dart
```

### 4. Mobile App Integration Tests

#### Widget Tests

- Navigation flow (all pages accessible)
- Transaction CRUD UI workflow
- Account management UI workflow
- Budget creation and tracking
- Import preview and execution
- Settings persistence

#### Integration Tests (Device)

- Full transaction lifecycle (create → edit → delete)
- Import from file → preview → import → verify
- Budget creation → spending → progress tracking
- Multi-account operations
- Theme switching persistence

#### Test Files

```
apps/mobile/test/
├── widget_test.dart                # Basic widget tests
├── integration/
│   ├── transaction_workflow_test.dart
│   ├── import_workflow_test.dart
│   ├── budget_workflow_test.dart
│   ├── account_workflow_test.dart
│   └── settings_workflow_test.dart
└── core/
    ├── router_test.dart
    ├── theme_test.dart
    └── providers_test.dart
```

## Test Execution Strategy

### Unit Tests (Fast)

Run on every commit:

```bash
flutter test
dart test packages/core
dart test packages/database
dart test packages/importers
dart test packages/sync
```

### Integration Tests (Medium)

Run on PR merge:

```bash
flutter test integration/
dart test packages/database/test/integration/
```

### Device Integration Tests (Slow)

Run before release:

```bash
flutter test integration/ --flavor production
```

## Test Data Management

### Test Fixtures

- Sample CSV files for each importer
- Sample transaction data for various scenarios
- Mock sync server responses
- Encrypted test data

### Test Database

- Use in-memory SQLite for unit tests
- Use temporary file database for integration tests
- Clean up after each test run

## Coverage Targets

| Package | Target | Current |
|---------|--------|---------|
| core | 80% | ~70% |
| database | 85% | ~75% |
| importers | 90% | ~85% |
| sync | 85% | ~80% |
| mobile app | 70% | ~60% |

## CI Integration

```yaml
test:
  steps:
    - run: flutter test --coverage
    - run: dart test packages/core --coverage
    - run: dart test packages/database --coverage
    - run: dart test packages/importers --coverage
    - run: dart test packages/sync --coverage
    - run: dart scripts/merge_coverage.dart
    - run: codecov upload
```

## Test Checklist Before Release

### v0.3.160 Release Criteria

- [ ] All unit tests pass
- [ ] Integration tests pass
- [ ] Database migration tests pass for all versions
- [ ] Import tests pass for all importers
- [ ] Sync server tests pass
- [ ] Mobile app widget tests pass
- [ ] Coverage meets targets
- [ ] No regression from previous release

## References

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Drift Database Testing](https://drift.simonbinder.eu/testing/)
- [Integration Testing Best Practices](https://docs.flutter.dev/testing/integration-tests)