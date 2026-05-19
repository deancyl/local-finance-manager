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
│   ├── importers/       # 金融机构导入器
│   ├── encryption/      # 加密模块
│   └── ai/              # AI分析模块
└── docs/                # 文档
```

## 开发进度

- [x] Phase 1.1: 项目设置
- [ ] Phase 1.2: 数据库schema
- [ ] Phase 1.3: 核心models
- [ ] Phase 1.4: 加密层
- [ ] Phase 1.5: 基础UI
- [ ] Phase 1.6-1.9: CRUD操作

## 快速开始

```bash
# 安装依赖
flutter pub get

# 运行应用
flutter run

# 运行测试
flutter test
```

## 许可证

MIT License