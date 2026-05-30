# Sync Server

Self-hosted sync server for Local Finance Manager with E2E encryption.

## Features

- Offline-first sync using PowerSync protocol
- End-to-end encryption for all sync data
- PostgreSQL backend
- Multi-device support
- Conflict detection and resolution
- WebSocket real-time notifications (v0.3.203)
- QR code device pairing (v0.3.204)
- Offline queue management (v0.3.204)

## Documentation

- **[Deployment Guide](../../docs/sync-server-deployment.md)** - Complete deployment instructions
- **[Testing Guide](../../docs/sync-testing-guide.md)** - Multi-device sync testing procedures
- **[Architecture](../../docs/SYNC_ARCHITECTURE.md)** - Technical architecture details

## Setup

### Prerequisites

- Dart SDK 3.5.0 or later
- PostgreSQL 14 or later

### Installation

```bash
# Install dependencies
dart pub get

# Copy environment file
cp .env.example .env

# Edit .env with your configuration
```

### Database Setup

```bash
# Create database
psql -U postgres -c "CREATE DATABASE finance_sync;"

# Run schema
psql -U postgres -d finance_sync -f database/schema.sql
```

### Running

```bash
# Development
dart run server.dart

# Production
dart compile exe server.dart
./server.exe
```

## API Endpoints

### Health Check
```
GET /health
```

### Authentication
```
POST /api/v1/auth/register
POST /api/v1/auth/login
```

### Sync
```
POST /api/v1/sync/upload
GET /api/v1/sync/download
```

### Devices
```
GET /api/v1/devices
POST /api/v1/devices/register
```

## Architecture

```
sync-server/
├── server.dart           # Main server entry point
├── src/
│   ├── database/         # Database connection
│   ├── models/           # Data models
│   ├── services/         # Business logic
│   └── middleware/       # Auth, encryption, etc.
├── database/
│   └── schema.sql        # Database schema
└── test/                 # Tests
```

## Security

- All data is encrypted end-to-end
- Device public keys are used for encryption
- JWT tokens for authentication
- No plaintext data stored on server

## License

MIT License

---

**Version**: v0.3.207

**Recent Changes**:
- v0.3.203: WebSocket real-time notifications
- v0.3.204: QR pairing and offline queue
- v0.3.205: Sync status indicator
- v0.3.207: Testing and deployment documentation