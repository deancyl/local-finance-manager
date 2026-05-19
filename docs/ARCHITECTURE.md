# Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CLIENT LAYER                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │   Mobile    │  │    Web      │  │  Desktop    │  │   Tablet    │   │
│  │  (Flutter)  │  │  (Flutter)  │  │  (Flutter)  │  │  (Flutter)  │   │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘   │
│         │                │                │                │           │
│         └────────────────┴────────────────┴────────────────┘           │
│                                   │                                      │
└───────────────────────────────────┼──────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         APPLICATION LAYER                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    State Management (Riverpod)                    │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐               │  │
│  │  │  Providers  │  │  Notifiers  │  │   States    │               │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘               │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                      Feature Modules                              │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐            │  │
│  │  │ Accounts │ │Transact- │ │Categories│ │ Budgets  │            │  │
│  │  │          │ │  ions    │ │          │ │          │            │  │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘            │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           DOMAIN LAYER                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                         Core Package                              │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐               │  │
│  │  │   Models    │  │Repositories │  │  Use Cases  │               │  │
│  │  │  (Domain)   │  │ (Interfaces)│  │ (Business)  │               │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘               │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           DATA LAYER                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐  │
│  │   Database        │  │   Encryption      │  │   Importers       │  │
│  │   (Drift/SQLite)  │  │   (AES-256-GCM)   │  │   (CSV/OFX)       │  │
│  └─────────┬─────────┘  └─────────┬─────────┘  └─────────┬─────────┘  │
│            │                      │                      │             │
│            └──────────────────────┴──────────────────────┘             │
│                                   │                                      │
└───────────────────────────────────┼──────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         INFRASTRUCTURE LAYER                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐  │
│  │   Local Storage   │  │   OS Keychain     │  │   Sync Server     │  │
│  │   (SQLite File)   │  │   (Secure Store)  │  │   (Optional)      │  │
│  └───────────────────┘  └───────────────────┘  └───────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Transaction Creation Flow

```
User Input
    │
    ▼
┌─────────────────┐
│ UI Widget       │
│ (AddTransaction │
│    Dialog)      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ TransactionNot- │
│ ifier (Riverpod)│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ LocalFinance    │
│ Database (Drift)│
└────────┬────────┘
         │
         ├────────────────────┐
         │                    │
         ▼                    ▼
┌─────────────────┐  ┌─────────────────┐
│ transactions    │  │ splits          │
│ table           │  │ table           │
└─────────────────┘  └─────────────────┘
         │
         ▼
┌─────────────────┐
│ SQLite File     │
│ (Encrypted)     │
└─────────────────┘
```

## State Management

### Riverpod Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ProviderScope (Root)                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Database Provider                        │   │
│  │  Provider<LocalFinanceDatabase>                      │   │
│  └───────────────────────┬─────────────────────────────┘   │
│                          │                                  │
│          ┌───────────────┼───────────────┐                 │
│          │               │               │                 │
│          ▼               ▼               ▼                 │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐          │
│  │  Accounts   │ │Transactions │ │ Categories  │          │
│  │  Provider   │ │  Provider   │ │  Provider   │          │
│  │  (Stream)   │ │  (Stream)   │ │  (Stream)   │          │
│  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘          │
│         │               │               │                  │
│         ▼               ▼               ▼                  │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐          │
│  │  Account    │ │Transaction  │ │ Category    │          │
│  │  Notifier   │ │  Notifier   │ │  Notifier   │          │
│  │  (State)    │ │  (State)    │ │  (State)    │          │
│  └─────────────┘ └─────────────┘ └─────────────┘          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Encryption Strategy

### Key Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                    User Password                             │
│                    (Memorized)                               │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            │ PBKDF2 (100,000 iterations)
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Master Key                                │
│                    (Derived)                                 │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            │ Stored in OS Keychain
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Database Key                              │
│                    (SQLCipher)                               │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            │ AES-256-GCM
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Encrypted Database                        │
│                    (SQLite File)                             │
└─────────────────────────────────────────────────────────────┘
```

### Platform Keychain

| Platform | Storage | Access Control |
|----------|---------|----------------|
| iOS | Keychain Services | kSecAttrAccessibleWhenUnlocked |
| Android | Android Keystore | EncryptedSharedPreferences |
| Windows | Credential Manager | DPAPI |
| macOS | Keychain Services | Touch ID optional |
| Linux | libsecret | Keyring |
| Web | IndexedDB | Web Crypto API |

## Sync Architecture (Phase 3)

### Sync Protocol

```
┌─────────────────┐                    ┌─────────────────┐
│  Device A       │                    │  Sync Server    │
│  (Local SQLite) │                    │  (PostgreSQL)   │
└────────┬────────┘                    └────────┬────────┘
         │                                      │
         │  1. Get checkpoint                   │
         │─────────────────────────────────────▶│
         │                                      │
         │  2. Return checkpoint                │
         │◀─────────────────────────────────────│
         │                                      │
         │  3. Send mutations (encrypted)       │
         │─────────────────────────────────────▶│
         │                                      │
         │  4. Validate & store                 │
         │                    ┌────────────────┐│
         │                    │ Conflict?      ││
         │                    │ Record & notify││
         │                    └────────────────┘│
         │                                      │
         │  5. Return new checkpoint            │
         │◀─────────────────────────────────────│
         │                                      │
         │  6. Pull changes (encrypted)         │
         │─────────────────────────────────────▶│
         │                                      │
         │  7. Return changes                   │
         │◀─────────────────────────────────────│
         │                                      │
         │  8. Merge & apply                    │
         │                                      │
└─────────┘                                      └─────────┘
```

## Import Pipeline (Phase 2)

### Import Flow

```
┌─────────────────┐
│  CSV/OFX File   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Format Detection│
│ (Alipay/WeChat/ │
│  Bank)          │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Parse & Normalize│
│ (Institution-   │
│  specific)      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Deduplication   │
│ (External ID +  │
│  Fuzzy Match)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Categorization  │
│ (Rules + AI)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Preview & Confirm│
│ (User Review)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Import & Audit  │
│ (Batch Record)  │
└─────────────────┘
```

## Security Considerations

### Data Protection

1. **At Rest**: SQLCipher with AES-256
2. **In Transit**: TLS 1.3 + E2E encryption
3. **In Memory**: Secure key storage in OS keychain

### Threat Model

| Threat | Mitigation |
|--------|------------|
| Device theft | Encrypted database, biometric unlock |
| Cloud provider breach | E2E encryption, server sees only encrypted blobs |
| Network interception | TLS + E2E encryption |
| Malicious app | Code signing, attestation |
| Key loss | Paper backup, recovery phrase |

## Performance Considerations

### Database Optimization

- Materialized balance tables for quick lookups
- Indexed columns: `post_date`, `account_id`, `external_id`
- WAL mode for concurrent reads/writes
- Lazy loading for large datasets

### UI Performance

- `StreamProvider` for reactive updates
- Pagination for transaction lists
- Background database operations with `NativeDatabase.createInBackground()`
- Computed properties cached in providers