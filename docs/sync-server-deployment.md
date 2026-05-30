# Sync Server Deployment Guide

## Overview

This guide covers deployment of the Local Finance Manager sync server. The sync server enables multi-device synchronization with end-to-end encryption.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Mobile/Desktop App                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │ Sync Client │  │ WebSocket   │  │ Offline Queue   │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
└───────────────────────────┬─────────────────────────────┘
                            │ HTTPS + WebSocket
                            ▼
┌─────────────────────────────────────────────────────────┐
│                      Sync Server                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │ API Server  │  │ WebSocket   │  │ Auth Service    │  │
│  │ (Dart Frog) │  │ Service     │  │ (JWT)           │  │
│  │ Port: 3000  │  │ Port: 3000  │  │                 │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
└───────────────────────────┬─────────────────────────────┘
                            │
          ┌─────────────────┴─────────────────┐
          ▼                                   ▼
┌─────────────────────┐            ┌─────────────────────┐
│   PowerSync         │            │   PostgreSQL        │
│   Service           │            │   Database          │
│   Port: 8080        │            │   Port: 5432        │
└─────────────────────┘            └─────────────────────┘
```

---

## Prerequisites

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 1 core | 2+ cores |
| RAM | 512 MB | 1+ GB |
| Storage | 1 GB | 5+ GB |
| Network | 1 Mbps | 10+ Mbps |

### Software Requirements

- **Docker** 20.10+ and Docker Compose 2.0+ (recommended)
- OR **Dart SDK** 3.5.0+ (for manual deployment)
- **PostgreSQL** 14+ (if not using Docker)
- **OpenSSL** (for key generation)

### Network Requirements

- Port 3000: API server (must be accessible from clients)
- Port 8080: PowerSync service (must be accessible from clients)
- Port 5432: PostgreSQL (internal only, or restricted)

---

## Deployment Options

### Option 1: Docker Compose (Recommended)

Best for: Most deployments, quick setup, easy management

#### Step 1: Prepare Configuration

```bash
# Navigate to sync server directory
cd apps/sync-server

# Copy environment template
cp .env.example .env

# Edit .env with your configuration
nano .env
```

#### Step 2: Generate Secrets

```bash
# Generate JWT secret (32+ characters)
openssl rand -base64 32

# Generate encryption key (32 bytes hex)
openssl rand -hex 32
```

Add generated values to `.env`:

```bash
# .env
JWT_SECRET=<your-generated-jwt-secret>
ENCRYPTION_KEY=<your-generated-encryption-key>
```

#### Step 3: Configure PowerSync

Create `powersync.yaml`:

```yaml
# PowerSync configuration
instance_name: finance-sync

# Database connection
database:
  url: postgresql://postgres:postgres@postgres:5432/finance_sync

# JWT authentication
auth:
  jwt_secret: ${JWT_SECRET}
  token_expiry: 604800  # 7 days in seconds

# Sync rules
sync:
  bucket_size: 1000
  max_upload_size: 10485760  # 10 MB
  max_download_size: 10485760  # 10 MB
```

#### Step 4: Deploy

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f api
```

#### Step 5: Verify Deployment

```bash
# Health check
curl http://localhost:3000/health
# Expected: {"status":"ok"}

# Check API version
curl http://localhost:3000/api/v1/version
# Expected: {"version":"0.3.207"}

# WebSocket test (requires wscat)
wscat -c ws://localhost:3000/ws
```

---

### Option 2: Manual Deployment

Best for: Custom environments, production tuning, cloud deployment

#### Step 1: Install Dependencies

```bash
# Install Dart SDK (if not already installed)
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install apt-transport-https
wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | sudo tee /etc/apt/sources.list.d/dart_stable.list
sudo apt-get update
sudo apt-get install dart

# Install PostgreSQL
sudo apt-get install postgresql postgresql-contrib
```

#### Step 2: Setup PostgreSQL

```bash
# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
sudo -u postgres psql -c "CREATE DATABASE finance_sync;"
sudo -u postgres psql -c "CREATE USER finance_user WITH PASSWORD 'secure_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE finance_sync TO finance_user;"

# Import schema
sudo -u postgres psql -d finance_sync -f database/schema.sql
```

#### Step 3: Configure Server

```bash
# Navigate to sync server directory
cd apps/sync-server

# Install dependencies
dart pub get

# Copy environment file
cp .env.example .env

# Edit configuration
nano .env
```

Configure `.env`:

```bash
HOST=0.0.0.0
PORT=3000
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=finance_sync
DATABASE_USER=finance_user
DATABASE_PASSWORD=secure_password
JWT_SECRET=your_jwt_secret
ENCRYPTION_KEY=your_encryption_key
```

#### Step 4: Run Server

```bash
# Development
dart run server.dart

# Production (compile executable)
dart compile exe server.dart -o sync-server

# Run with systemd (Linux)
sudo nano /etc/systemd/system/finance-sync.service
```

Systemd service file:

```ini
[Unit]
Description=Finance Sync Server
After=network.target postgresql.service

[Service]
Type=simple
User=finance
WorkingDirectory=/opt/finance-sync
ExecStart=/opt/finance-sync/sync-server
Restart=always
RestartSec=10
EnvironmentFile=/opt/finance-sync/.env

[Install]
WantedBy=multi-user.target
```

Enable service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable finance-sync
sudo systemctl start finance-sync
sudo systemctl status finance-sync
```

---

### Option 3: Cloud Deployment

#### AWS EC2 Deployment

```bash
# Launch EC2 instance (t3.small recommended)
# Security group ports: 22, 3000, 8080

# SSH to instance
ssh ubuntu@<ec2-public-ip>

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Logout and login again for group change
exit
ssh ubuntu@<ec2-public-ip>

# Clone repository
git clone https://github.com/deancyl/local-finance-manager.git
cd local-finance-manager/apps/sync-server

# Configure and deploy
cp .env.example .env
nano .env  # Add secrets
docker-compose up -d

# Test
curl http://localhost:3000/health
```

#### Google Cloud Run Deployment

```dockerfile
# Add to apps/sync-server/Dockerfile.cloudrun
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart compile exe server.dart -o server

FROM gcr.io/distroless/cc
COPY --from=build /app/server /app/server
EXPOSE 3000
CMD ["/app/server"]
```

Deploy:

```bash
# Build and push
gcloud builds submit --tag gcr.io/PROJECT_ID/finance-sync

# Deploy to Cloud Run
gcloud run deploy finance-sync \
  --image gcr.io/PROJECT_ID/finance-sync \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "DATABASE_HOST=/cloudsql/PROJECT_ID:REGION:INSTANCE_NAME"
```

---

## Configuration Reference

### Environment Variables

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `HOST` | No | Server bind address | `0.0.0.0` |
| `PORT` | No | Server port | `3000` |
| `DATABASE_HOST` | Yes | PostgreSQL host | - |
| `DATABASE_PORT` | No | PostgreSQL port | `5432` |
| `DATABASE_NAME` | Yes | Database name | - |
| `DATABASE_USER` | Yes | Database user | - |
| `DATABASE_PASSWORD` | Yes | Database password | - |
| `JWT_SECRET` | Yes | JWT signing secret | - |
| `ENCRYPTION_KEY` | Yes | E2E encryption key (32 bytes hex) | - |
| `POWERSYNC_ENDPOINT` | No | PowerSync service URL | `http://localhost:8080` |

### JWT Configuration

```dart
// JWT token settings
const jwtIssuer = 'local-finance-sync';
const jwtAudience = 'finance-app';
const tokenExpiryDays = 7;  // 7 days
const refreshExpiryDays = 30;  // 30 days
```

### WebSocket Configuration

```dart
// WebSocket settings
const wsHeartbeatInterval = Duration(seconds: 30);
const wsReconnectDelay = Duration(seconds: 5);
const wsMaxReconnectAttempts = 5;
```

---

## SSL/TLS Configuration

### Option 1: Reverse Proxy (Recommended)

Use Nginx or Caddy for SSL termination:

```nginx
# /etc/nginx/sites-available/finance-sync
server {
    listen 443 ssl http2;
    server_name sync.example.com;

    ssl_certificate /etc/letsencrypt/live/sync.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/sync.example.com/privkey.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Option 2: Let's Encrypt with Certbot

```bash
# Install Certbot
sudo apt-get install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d sync.example.com

# Auto-renewal
sudo systemctl enable certbot.timer
```

---

## Monitoring & Logging

### Health Check Endpoint

```bash
# Automated health check
curl -f http://localhost:3000/health || exit 1
```

### Log Configuration

```yaml
# docker-compose.yml - Add logging configuration
services:
  api:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### Prometheus Metrics

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'finance-sync'
    static_configs:
      - targets: ['localhost:3000']
```

---

## Backup & Recovery

### Database Backup

```bash
# Backup
docker exec finance-postgres pg_dump -U postgres finance_sync > backup_$(date +%Y%m%d).sql

# Restore
cat backup_20240101.sql | docker exec -i finance-postgres psql -U postgres finance_sync
```

### Automated Backup Script

```bash
#!/bin/bash
# backup.sh
BACKUP_DIR="/var/backups/finance-sync"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR
docker exec finance-postgres pg_dump -U postgres finance_sync | gzip > $BACKUP_DIR/backup_$DATE.sql.gz

# Keep only last 7 backups
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +7 -delete
```

Cron job:

```bash
# Daily backup at 2 AM
0 2 * * * /opt/finance-sync/backup.sh
```

---

## Security Hardening

### Network Security

1. **Firewall Rules**:
   ```bash
   # UFW (Ubuntu)
   sudo ufw allow 3000/tcp
   sudo ufw allow 8080/tcp
   sudo ufw enable
   ```

2. **Rate Limiting** (Nginx):
   ```nginx
   limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
   
   location /api/ {
       limit_req zone=api burst=20 nodelay;
       proxy_pass http://localhost:3000;
   }
   ```

### Application Security

1. **Secrets Management**:
   - Never commit `.env` to version control
   - Use Docker secrets or Kubernetes secrets in production
   - Rotate secrets periodically

2. **JWT Security**:
   - Use strong JWT secret (32+ random characters)
   - Implement token refresh mechanism
   - Set appropriate token expiry

3. **Database Security**:
   - Use strong database passwords
   - Restrict database access to localhost
   - Enable SSL for database connections

---

## Scaling

### Horizontal Scaling

```yaml
# docker-compose.scale.yml
version: '3.8'
services:
  api:
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '1'
          memory: 512M
    environment:
      - DATABASE_HOST=postgres
      - DATABASE_POOL_SIZE=20

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - api
```

### Load Balancer Configuration

```nginx
upstream sync_backend {
    least_conn;
    server api-1:3000;
    server api-2:3000;
    server api-3:3000;
}

server {
    location / {
        proxy_pass http://sync_backend;
    }
}
```

---

## Troubleshooting

### Common Issues

#### 1. Database Connection Failed

```
Error: Connection refused (DATABASE_HOST=localhost)
```

**Solution**:
- Check PostgreSQL is running: `docker-compose ps postgres`
- Verify database credentials in `.env`
- Check network connectivity: `telnet localhost 5432`

#### 2. JWT Secret Not Set

```
Error: JWT_SECRET is required
```

**Solution**:
- Ensure `.env` file exists with `JWT_SECRET=...`
- Generate new secret: `openssl rand -base64 32`
- Restart containers: `docker-compose restart`

#### 3. Port Already in Use

```
Error: bind: address already in use
```

**Solution**:
- Find process: `lsof -i :3000`
- Kill process: `kill -9 <PID>`
- Or change port in `.env`

#### 4. WebSocket Connection Drops

**Symptoms**: Frequent disconnections, sync lag

**Solutions**:
- Check network stability
- Increase heartbeat interval
- Check firewall timeout settings
- Review server resource usage

### Log Analysis

```bash
# View recent errors
docker-compose logs api | grep -i error | tail -20

# View WebSocket connections
docker-compose logs api | grep -i websocket

# Monitor in real-time
docker-compose logs -f --tail=100 api
```

---

## Upgrade Guide

### Version Upgrade

```bash
# Backup database
docker exec finance-postgres pg_dump -U postgres finance_sync > backup_pre_upgrade.sql

# Pull latest code
git pull origin main

# Rebuild and restart
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Verify
curl http://localhost:3000/health
```

### Schema Migration

If database schema changes:

```bash
# Check for new migrations
ls database/migrations/

# Apply migrations
docker exec -i finance-postgres psql -U postgres finance_sync < database/migrations/001_add_column.sql
```

---

## Related Documentation

- [Sync Testing Guide](./sync-testing-guide.md)
- [Sync Architecture](./SYNC_ARCHITECTURE.md)
- [API Documentation](./API.md)
- [Security Guide](./SECURITY.md)
