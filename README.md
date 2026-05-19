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

### Phase 2: Import System (待开始)

- [ ] Import pipeline architecture
- [ ] Alipay importer
- [ ] WeChat Pay importer
- [ ] ICBC/CCB/BOC importers

## 快速开始

```bash
# 安装依赖
cd finance-app/apps/mobile
flutter pub get

# 运行应用
flutter run

# 运行测试
flutter test
```

## GitHub

https://github.com/deancyl/local-finance-manager

## 许可证

MIT License