# Development Guide

## Project Overview

**Local Finance Manager** is a local-first personal finance application designed for maximum privacy and cross-platform support.

### Key Features
- Local-first architecture (works offline)
- End-to-end encryption for sync
- Multi-platform support (iOS, Android, Web, Windows, macOS, Linux)
- Chinese financial institution import support
- Optional local AI analysis

## Getting Started

### Prerequisites
- Flutter SDK 3.24.5 or later
- Dart SDK 3.5.0 or later
- Android Studio / Xcode (for mobile development)
- VS Code with Flutter extension (recommended)

### Installation

```bash
# Clone the repository
git clone https://github.com/deancyl/local-finance-manager.git
cd local-finance-manager

# Install dependencies for mobile app
cd apps/mobile
flutter pub get

# Generate Drift database code
flutter pub run build_runner build

# Run the app
flutter run
```

### Project Structure

```
finance-app/
├── apps/
│   ├── mobile/                    # Flutter mobile app
│   │   ├── lib/
│   │   │   ├── core/              # Core functionality
│   │   │   │   ├── router/        # GoRouter configuration
│   │   │   │   └── theme/         # Material 3 theme
│   │   │   ├── features/          # Feature modules
│   │   │   │   ├── accounts/      # Account management
│   │   │   │   ├── transactions/  # Transaction management
│   │   │   │   ├── categories/    # Category management
│   │   │   │   ├── budgets/       # Budget tracking
│   │   │   │   ├── reports/       # Reports and analytics
│   │   │   │   └── settings/      # App settings
│   │   │   └── main.dart
│   │   └── pubspec.yaml
│   └── sync-server/               # Self-hosted sync server (Phase 3)
│
├── packages/
│   ├── core/                      # Shared business logic
│   │   ├── lib/
│   │   │   ├── models/            # Domain models
│   │   │   ├── repositories/      # Repository interfaces
│   │   │   └── usecases/          # Business logic
│   │   └── pubspec.yaml
│   │
│   ├── database/                  # Drift database layer
│   │   ├── lib/
│   │   │   ├── tables/            # Table definitions
│   │   │   ├── daos/              # Data Access Objects
│   │   │   └── database.dart      # Database class
│   │   └── pubspec.yaml
│   │
│   ├── encryption/                # Encryption module
│   │   ├── lib/
│   │   │   ├── keychain/          # Platform keychain
│   │   │   └── crypto/            # AES-256-GCM
│   │   └── pubspec.yaml
│   │
│   ├── importers/                 # Financial institution importers
│   │   └── pubspec.yaml
│   │
│   └── ai/                        # Local AI integration
│       └── pubspec.yaml
│
├── docs/                          # Documentation
├── melos.yaml                     # Monorepo configuration
└── pubspec.yaml                   # Root pubspec
```

## Architecture

### State Management
- **Riverpod** for reactive state management
- `StateNotifier` for complex state with async operations
- `StreamProvider` for database watch queries

### Database
- **Drift** (SQLite ORM) for type-safe database operations
- Tables defined with Dart code generation
- DAOs for encapsulated data access

### Navigation
- **GoRouter** for declarative routing
- Shell routes for bottom navigation
- Deep linking support (planned)

### Encryption
- **SQLCipher** for database encryption at rest
- **flutter_secure_storage** for keychain access
- **AES-256-GCM** for data encryption

## Development Workflow

### Running Tests
```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/features/accounts/account_test.dart
```

### Code Generation
```bash
# Generate Drift database code
flutter pub run build_runner build

# Watch for changes
flutter pub run build_runner watch
```

### Building
```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release

# Windows
flutter build windows --release
```

## Database Schema

### Core Tables

#### `accounts`
| Column | Type | Description |
|--------|------|-------------|
| id | TEXT | Primary key (UUID) |
| name | TEXT | Account name |
| account_type | TEXT | ASSET, LIABILITY, EQUITY, INCOME, EXPENSE |
| parent_id | TEXT | Parent account (hierarchy) |
| commodity_id | TEXT | Currency (FK to commodities) |
| code | TEXT | Account number |
| description | TEXT | Notes |
| created_at | INTEGER | Creation timestamp |
| updated_at | INTEGER | Last update timestamp |

#### `transactions`
| Column | Type | Description |
|--------|------|-------------|
| id | TEXT | Primary key (UUID) |
| description | TEXT | Transaction description |
| post_date | INTEGER | Transaction date |
| enter_date | INTEGER | Entry date |
| currency_id | TEXT | Currency (FK) |
| notes | TEXT | Additional notes |
| external_id | TEXT | Bank transaction ID |
| is_double_entry | BOOL | Double-entry mode flag |
| created_at | INTEGER | Creation timestamp |

#### `splits`
| Column | Type | Description |
|--------|------|-------------|
| id | TEXT | Primary key (UUID) |
| transaction_id | TEXT | Parent transaction (FK) |
| account_id | TEXT | Account (FK) |
| value_num | INTEGER | Amount numerator |
| value_denom | INTEGER | Amount denominator |
| reconcile_state | TEXT | n/c/y/v (none/cleared/reconciled/voided) |

## Feature Modules

### Account Management
- Create/edit/delete accounts
- Hierarchical account structure
- Asset and liability account types
- Account icons based on name

### Transaction Management
- Single-entry transactions (default)
- Income/expense toggle
- Date selection
- Account selection
- Description and notes

### Category Management
- Pre-seeded expense categories
- Pre-seeded income categories
- Custom category support
- Icon and color customization

### Reports
- Income/expense summary
- Balance calculation
- Monthly trend (planned)

## Contributing

### Commit Convention
```
feat: Add new feature
fix: Fix bug
docs: Update documentation
refactor: Code refactoring
test: Add tests
chore: Maintenance tasks
```

### Branch Strategy
- `main` - Stable releases
- `develop` - Development branch
- `feature/*` - Feature branches
- `fix/*` - Bug fix branches

## Roadmap

### Phase 1: Foundation ✅ (Completed)
- Project setup
- Database layer
- Core models
- Encryption
- Basic UI
- CRUD operations

### Phase 2: Import System (Next)
- Import pipeline
- Alipay importer
- WeChat Pay importer
- Bank importers

### Phase 3: Sync System
- Sync server
- PowerSync integration
- Conflict resolution
- E2EE for sync

### Phase 4: Double-Entry
- Double-entry mode toggle
- Split editor
- Reconciliation workflow

### Phase 5: AI Integration
- Local LLM setup
- Transaction categorization
- Natural language queries
- Spending insights

### Phase 6: Advanced Features
- Budget management
- Multi-currency
- Advanced reports
- Export functionality

## License

MIT License - See [LICENSE](LICENSE) for details.