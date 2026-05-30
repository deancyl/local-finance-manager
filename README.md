# 本地金融管家 (Local Finance Manager)

本地优先的个人金融资产管理软件，支持多平台、多设备同步、最高隐私保护。

## 功能特性

- 🏦 **多机构导入**: 支持支付宝、微信支付、工商银行、建设银行、中国银行等
- 🔐 **本地加密**: SQLCipher加密存储，OS密钥链保护
- 🔄 **多设备同步**: 自托管同步服务器，端到端加密
- 📊 **智能分析**: 本地AI分析，无需云端
- 💰 **预算管理**: 分类预算、预警提醒
- 📈 **复式记账**: 可选复式记账模式

## 技术栈

- **框架**: Flutter (跨平台)
- **数据库**: Drift (SQLite ORM) + SQLCipher
- **同步**: PowerSync
- **后端**: Dart Frog + PostgreSQL
- **AI**: Ollama (桌面) / llama.cpp (移动)

## 项目结构

```
finance-app/
├── apps/
│   ├── mobile/          # Flutter移动应用
│   ├── desktop/         # Flutter桌面应用
│   └── sync-server/     # 同步服务器
├── packages/
│   ├── core/            # 核心业务逻辑
│   ├── database/        # Drift数据库层
│   ├── encryption/      # 加密模块
│   ├── importers/       # 金融机构导入器
│   ├── sync/            # 同步客户端
│   └── ai/              # AI分析模块
└── docs/                # 文档
```

## 开发进度

### Phase 1: Foundation ✅ 完成

- [x] Phase 1.1: 项目设置（monorepo、Git、CI/CD）
- [x] Phase 1.2: 数据库schema + Drift设置
- [x] Phase 1.3: 核心models + repositories
- [x] Phase 1.4: 加密层（SQLCipher + keychain）
- [x] Phase 1.5: 基础UI shell（导航、主题）
- [x] Phase 1.6: 账户管理CRUD
- [x] Phase 1.7: 交易CRUD（单式记账）
- [x] Phase 1.8: 分类管理
- [x] Phase 1.9: 基础报表（收支）

### Phase 2: Import System ✅ 完成

- [x] Import pipeline architecture
- [x] Alipay importer (支付宝)
- [x] WeChat Pay importer (微信支付)
- [x] ICBC/CCB/BOC importers (工商银行/建设银行/中国银行)
- [x] Import preview UI
- [x] Duplicate detection

### Phase 3: Sync System ✅ 完成

- [x] Sync server setup (Dart Frog + PostgreSQL)
- [x] PowerSync integration
- [x] E2E encryption for sync
- [x] Conflict resolution (finance-specific rules)
- [x] Mobile app sync UI
- [x] Device management

### v0.3.x Roadmap (进行中)

- [x] v0.3.120: Performance & Stability optimizations
  - [x] Lazy loading transaction list with pagination
  - [x] Memory optimization with provider disposal
  - [x] Startup optimization with deferred initialization
  - [x] Error recovery with retry mechanisms
  - [x] Background sync service
- [x] v0.3.194-v0.3.200: Double-Entry Bookkeeping
  - [x] v0.3.194: Journal entry list and management
  - [x] v0.3.195: Drill-down navigation from reports
  - [x] v0.3.196: Account hierarchy validation
  - [x] v0.3.197: Enhanced error handling and progress tracking
  - [x] v0.3.198: Backup verification and migration safety
  - [x] v0.3.199: Performance indexes and caching
  - [x] v0.3.200: Loading states, error states, UI polish
- [ ] v0.3.201+: WebSocket real-time sync notifications
- [ ] QR code device pairing
- [ ] Sync status indicator in app bar
- [ ] Offline queue visualization
- [ ] Multi-device sync testing

### Phase 4: Double-Entry Bookkeeping ✅ 完成

- [x] Full double-entry transaction support
- [x] Account hierarchy management
- [x] Journal entry editor
- [x] Trial balance report
- [x] Balance sheet report
- [x] Income statement report

### Version History

#### v0.3.194 - v0.3.200: Double-Entry Bookkeeping
- v0.3.194: Journal entry list and management
- v0.3.195: Drill-down navigation from reports
- v0.3.196: Account hierarchy validation
- v0.3.197: Enhanced error handling and progress tracking
- v0.3.198: Backup verification and migration safety
- v0.3.199: Performance indexes and caching
- v0.3.200: Loading states, error states, UI polish

### Phase 5: AI Integration (计划中 v0.4.1-v0.4.5)

- [ ] Local AI setup (Ollama/llama.cpp)
- [ ] Transaction categorization
- [ ] Spending pattern analysis
- [ ] Budget recommendations
- [ ] Anomaly detection

## 快速开始

### 移动应用

```bash
# 安装依赖
cd finance-app/apps/mobile
flutter pub get

# 运行应用
flutter run

# 运行测试
flutter test
```

### 同步服务器

```bash
# 安装依赖
cd finance-app/apps/sync-server
dart pub get

# 配置环境变量
cp .env.example .env
# 编辑 .env 文件

# 运行服务器
dart run server.dart

# 或使用 Docker
docker-compose up -d
```

## 同步功能使用

### 1. 部署同步服务器

```bash
# 使用 Docker Compose
cd apps/sync-server
docker-compose up -d
```

服务包含：
- PowerSync (端口 8080)
- PostgreSQL (端口 5432)
- API Server (端口 3000)

### 2. 配置移动应用

1. 打开应用 → 设置 → 同步设置
2. 输入服务器地址 (如: `http://192.168.1.100:3000`)
3. 注册账户或登录
4. 设备自动注册
5. 点击"同步"按钮开始同步

### 3. 多设备同步

- 每个设备自动获得唯一设备ID
- 数据按时间戳同步
- 冲突自动检测：
  - 删除操作优先
  - 已对账交易需手动解决
  - 金额变更需手动确认
  - 其他字段自动合并

## 安全特性

### 本地加密
- SQLCipher 数据库加密
- AES-256-GCM 数据加密
- PBKDF2 密钥派生 (100,000 次迭代)
- iOS Keychain / Android Keystore 密钥存储

### 同步安全
- JWT 令牌认证 (7天有效期)
- 端到端加密 (E2E)
- 服务器无法解密同步数据
- 设备公钥验证

### 隐私保护
- 所有数据本地存储
- 无云端依赖
- 可选自托管同步
- AI 功能完全本地运行

## GitHub

https://github.com/deancyl/local-finance-manager

## 许可证

MIT License