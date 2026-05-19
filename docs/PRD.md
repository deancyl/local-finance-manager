# Product Requirements Document (PRD)

## Document Information

| Property | Value |
|----------|-------|
| **Product Name** | 本地金融管家 (Local Finance Manager) |
| **Version** | 1.0.0 |
| **Last Updated** | 2026-05-19 |
| **Status** | Active Development |
| **Target Release** | v1.0.0 (12 months) |

---

## 1. Executive Summary

### 1.1 Product Vision

**本地金融管家** 是一款本地优先的个人金融资产管理软件，旨在为用户提供最高级别的隐私保护，同时支持多平台使用和多设备同步。

### 1.2 Problem Statement

| Problem | Current Solutions | Gap |
|---------|-------------------|-----|
| **隐私担忧** | 云端记账应用 | 数据存储在第三方服务器 |
| **多平台碎片化** | 各平台独立应用 | 数据不互通 |
| **中国金融机构支持不足** | 国际化应用 | 不支持支付宝、微信支付等 |
| **AI依赖云端** | 云端AI分析 | 隐私泄露风险 |
| **记账灵活性** | 单一记账模式 | 无法切换单式/复式记账 |

### 1.3 Solution Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      SOLUTION ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    LOCAL-FIRST CORE                              │   │
│  │  • All data stored locally by default                           │   │
│  │  • Works completely offline                                     │   │
│  │  • User controls all encryption keys                            │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    MULTI-PLATFORM                                │   │
│  │  • iOS, Android, Web, Windows, macOS, Linux                     │   │
│  │  • Single codebase (Flutter)                                    │   │
│  │  • Consistent experience across platforms                       │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    OPTIONAL SYNC                                 │   │
│  │  • Self-hosted sync server                                      │   │
│  │  • End-to-end encryption                                        │   │
│  │  • User controls sync timing                                    │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    CHINESE INSTITUTIONS                          │   │
│  │  • Alipay, WeChat Pay import                                    │   │
│  │  • Major banks (ICBC, CCB, BOC)                                 │   │
│  │  • Automatic categorization                                     │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    LOCAL AI                                      │   │
│  │  • Runs entirely on device                                      │   │
│  │  • No cloud dependency                                          │   │
│  │  • Graceful degradation when unavailable                        │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Target Users

### 2.1 User Personas

#### Persona 1: 隐私意识用户 (Privacy-Conscious User)

| Attribute | Description |
|-----------|-------------|
| **姓名** | 张明 (35岁，软件工程师) |
| **背景** | 关注数据隐私，不信任云端服务 |
| **需求** | 本地存储，端到端加密，自托管同步 |
| **痛点** | 现有记账应用都要求云端账号 |
| **成功指标** | 数据完全在本地，可离线使用 |

#### Persona 2: 多设备用户 (Multi-Device User)

| Attribute | Description |
|-----------|-------------|
| **姓名** | 李华 (28岁，产品经理) |
| **背景** | 使用iPhone、Windows电脑、iPad |
| **需求** | 跨平台同步，无缝切换 |
| **痛点** | 手机记账后电脑上看不到 |
| **成功指标** | 任意设备都能查看和编辑 |

#### Persona 3: 重度用户 (Power User)

| Attribute | Description |
|-----------|-------------|
| **姓名** | 王强 (42岁，财务总监) |
| **背景** | 专业财务背景，需要复式记账 |
| **需求** | 复式记账，报表分析，预算管理 |
| **痛点** | 个人记账软件功能太简单 |
| **成功指标** | 专业级功能，个人级易用性 |

#### Persona 4: AI辅助用户 (AI-Assisted User)

| Attribute | Description |
|-----------|-------------|
| **姓名** | 陈雪 (25岁，设计师) |
| **背景** | 不喜欢手动分类，希望AI自动处理 |
| **需求** | 智能分类，消费洞察，预算提醒 |
| **痛点** | 手动分类太繁琐 |
| **成功指标** | 90%+自动分类准确率 |

### 2.2 User Stories

#### Phase 1: Foundation (Completed)

| ID | User Story | Acceptance Criteria | Priority |
|----|------------|---------------------|----------|
| US-001 | 作为用户，我希望创建账户来管理我的资产 | 1. 可创建资产/负债账户<br>2. 可设置账户名称和类型<br>3. 账户列表按类型分组显示 | High |
| US-002 | 作为用户，我希望记录收入和支出 | 1. 可选择收入/支出类型<br>2. 可输入金额、日期、描述<br>3. 交易按日期分组显示 | High |
| US-003 | 作为用户，我希望查看收支概览 | 1. 首页显示净资产<br>2. 显示总收入和总支出<br>3. 显示结余金额 | Medium |

#### Phase 2: Import System

| ID | User Story | Acceptance Criteria | Priority |
|----|------------|---------------------|----------|
| US-010 | 作为用户，我希望导入支付宝账单 | 1. 支持CSV格式<br>2. 自动识别交易类型<br>3. 检测并标记重复交易 | High |
| US-011 | 作为用户，我希望导入微信支付账单 | 1. 支持CSV格式<br>2. 处理反引号前缀<br>3. 正确解析交易类型 | High |
| US-012 | 作为用户，我希望导入银行账单 | 1. 支持ICBC/CCB/BOC<br>2. 自动检测银行类型<br>3. 处理不同编码(GBK/UTF-8) | High |
| US-013 | 作为用户，我希望预览导入结果 | 1. 显示导入数量<br>2. 显示重复数量<br>3. 显示错误详情 | Medium |
| US-014 | 作为用户，我希望手动映射分类 | 1. 导入时可选择分类<br>2. 记住映射规则<br>3. 支持批量修改 | Medium |

#### Phase 3: Sync System

| ID | User Story | Acceptance Criteria | Priority |
|----|------------|---------------------|----------|
| US-020 | 作为用户，我希望同步数据到其他设备 | 1. 可配置同步服务器<br>2. 显示同步状态<br>3. 支持手动触发同步 | High |
| US-021 | 作为用户，我希望离线使用应用 | 1. 离线时所有功能可用<br>2. 自动队列待同步数据<br>3. 恢复网络后自动同步 | High |
| US-022 | 作为用户，我希望解决同步冲突 | 1. 检测冲突并通知<br>2. 显示冲突详情<br>3. 提供解决选项 | Medium |

#### Phase 4: Double-Entry

| ID | User Story | Acceptance Criteria | Priority |
|----|------------|---------------------|----------|
| US-030 | 作为用户，我希望使用复式记账 | 1. 可切换记账模式<br>2. 自动创建平衡分录<br>3. 验证借贷平衡 | Medium |
| US-031 | 作为用户，我希望进行账户对账 | 1. 导入银行对账单<br>2. 匹配交易记录<br>3. 标记已对账项目 | Medium |

#### Phase 5: AI Integration

| ID | User Story | Acceptance Criteria | Priority |
|----|------------|---------------------|----------|
| US-040 | 作为用户，我希望AI自动分类交易 | 1. 本地AI处理<br>2. 准确率>85%<br>3. 可手动纠正 | High |
| US-041 | 作为用户，我希望询问消费情况 | 1. 自然语言查询<br>2. 返回准确答案<br>3. 支持中文 | Medium |
| US-042 | 作为用户，我希望收到消费洞察 | 1. 异常消费提醒<br>2. 趋势分析<br>3. 节省建议 | Medium |

---

## 3. Functional Requirements

### 3.1 Core Features

#### F1: Account Management

| Requirement | Description | Priority | Phase |
|-------------|-------------|----------|-------|
| F1.1 | 创建/编辑/删除账户 | CRUD操作 | High | 1 |
| F1.2 | 账户类型分类 | 资产/负债/权益/收入/支出 | High | 1 |
| F1.3 | 账户层级结构 | 支持父子账户 | Medium | 1 |
| F1.4 | 多币种支持 | CNY, USD, EUR等 | Medium | 6 |
| F1.5 | 账户余额显示 | 实时计算 | High | 1 |

#### F2: Transaction Management

| Requirement | Description | Priority | Phase |
|-------------|-------------|----------|-------|
| F2.1 | 创建/编辑/删除交易 | CRUD操作 | High | 1 |
| F2.2 | 收入/支出切换 | 一键切换类型 | High | 1 |
| F2.3 | 交易分类 | 关联分类 | High | 1 |
| F2.4 | 交易搜索 | 按日期/金额/描述搜索 | Medium | 1 |
| F2.5 | 交易筛选 | 按账户/分类/日期范围 | Medium | 1 |
| F2.6 | 附件支持 | 添加收据图片 | Low | 6 |

#### F3: Category Management

| Requirement | Description | Priority | Phase |
|-------------|-------------|----------|-------|
| F3.1 | 预设分类 | 餐饮、交通、购物等 | High | 1 |
| F3.2 | 自定义分类 | 用户创建分类 | High | 1 |
| F3.3 | 分类图标/颜色 | 视觉区分 | Medium | 1 |
| F3.4 | 分类层级 | 支持子分类 | Low | 6 |

#### F4: Import System

| Requirement | Description | Priority | Phase |
|-------------|-------------|----------|-------|
| F4.1 | 支付宝导入 | CSV格式 | High | 2 |
| F4.2 | 微信支付导入 | CSV格式 | High | 2 |
| F4.3 | 银行账单导入 | ICBC/CCB/BOC | High | 2 |
| F4.4 | 重复检测 | 基于外部ID和模糊匹配 | High | 2 |
| F4.5 | 导入预览 | 显示解析结果 | Medium | 2 |
| F4.6 | 分类映射 | 手动/自动分类 | Medium | 2 |
| F4.7 | OFX/QIF支持 | 国际标准格式 | Low | 2 |

#### F5: Sync System

| Requirement | Description | Priority | Phase |
|-------------|-------------|----------|-------|
| F5.1 | 自托管服务器 | 用户自行部署 | High | 3 |
| F5.2 | 端到端加密 | E2EE for sync | High | 3 |
| F5.3 | 冲突检测 | 自动检测 | High | 3 |
| F5.4 | 冲突解决 | 手动/自动 | Medium | 3 |
| F5.5 | 离线队列 | 离线操作队列 | High | 3 |
| F5.6 | 同步状态 | 显示同步进度 | Medium | 3 |

#### F6: AI Features

| Requirement | Description | Priority | Phase |
|-------------|-------------|----------|-------|
| F6.1 | 交易自动分类 | 本地AI分类 | High | 5 |
| F6.2 | 自然语言查询 | 中文问答 | Medium | 5 |
| F6.3 | 消费洞察 | 异常检测 | Medium | 5 |
| F6.4 | 预算建议 | AI建议 | Low | 5 |
| F6.5 | 收据OCR | 图片识别 | Low | 5 |
| F6.6 | 降级策略 | 无AI时降级 | High | 5 |

### 3.2 Feature Prioritization Matrix

```
                    High Value
                         │
           F1.1 F2.1     │     F4.1 F4.2 F4.3
           F1.2 F2.2     │     F5.1 F5.2 F5.3
           F1.5 F2.3     │     F6.1
                         │
    Low Effort ──────────┼────────── High Effort
                         │
           F3.1 F3.2     │     F5.4 F6.2 F6.3
           F2.4 F2.5     │     F4.4 F4.5 F4.6
           F1.3          │     F1.4 F6.4 F6.5
                         │
                    Low Value
```

---

## 4. Non-Functional Requirements

### 4.1 Performance

| Metric | Target | Measurement |
|--------|--------|-------------|
| **冷启动时间** | <3秒 | 首次打开到可交互 |
| **交易列表加载** | <100ms | 1000条交易 |
| **导入处理** | <5秒 | 1000条CSV |
| **同步延迟** | <10秒 | 单次同步完成 |
| **内存占用** | <200MB | 正常使用 |

### 4.2 Reliability

| Metric | Target | Measurement |
|--------|--------|-------------|
| **数据丢失** | 0% | 本地数据持久化 |
| **崩溃率** | <0.1% | 会话崩溃比例 |
| **同步成功率** | >99% | 成功同步/总同步 |
| **离线可用性** | 100% | 核心功能离线可用 |

### 4.3 Security

| Requirement | Implementation |
|-------------|----------------|
| **数据加密** | SQLCipher (AES-256-GCM) |
| **密钥存储** | OS Keychain |
| **传输加密** | TLS 1.3 + E2E |
| **认证** | 密码 + 生物识别 |

### 4.4 Usability

| Metric | Target |
|--------|--------|
| **学习曲线** | <5分钟上手 |
| **核心流程步骤** | <3步完成记账 |
| **错误提示** | 清晰可操作 |
| **帮助文档** | 内嵌引导 |

### 4.5 Compatibility

| Platform | Minimum Version |
|----------|-----------------|
| **iOS** | iOS 14.0+ |
| **Android** | Android 8.0+ (API 26) |
| **Web** | Chrome 90+, Safari 14+, Firefox 90+ |
| **Windows** | Windows 10+ |
| **macOS** | macOS 11.0+ |
| **Linux** | Ubuntu 20.04+ |

---

## 5. User Interface Requirements

### 5.1 Design Principles

1. **简洁优先**: 核心功能一目了然
2. **一致性**: 跨平台统一体验
3. **可访问性**: 支持屏幕阅读器
4. **本地化**: 中文优先，支持英文

### 5.2 Navigation Structure

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         APP STRUCTURE                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Bottom Navigation (5 tabs)                                             │
│  ├── 首页 (Home)                                                        │
│  │   ├── 净资产卡片                                                      │
│  │   ├── 快捷操作                                                        │
│  │   └── 最近交易                                                        │
│  │                                                                       │
│  ├── 交易 (Transactions)                                                │
│  │   ├── 交易列表                                                        │
│  │   ├── 添加交易 (FAB)                                                 │
│  │   └── 搜索/筛选                                                       │
│  │                                                                       │
│  ├── 账户 (Accounts)                                                    │
│  │   ├── 账户列表                                                        │
│  │   └── 添加账户 (FAB)                                                 │
│  │                                                                       │
│  ├── 预算 (Budgets)                                                     │
│  │   ├── 预算列表                                                        │
│  │   └── 添加预算 (FAB)                                                 │
│  │                                                                       │
│  └── 报表 (Reports)                                                     │
│      ├── 收支概览                                                        │
│      ├── 月度趋势                                                        │
│      └── 分类统计                                                        │
│                                                                          │
│  Settings (from Home)                                                   │
│  ├── 安全设置                                                            │
│  ├── 数据备份                                                            │
│  ├── 同步设置                                                            │
│  ├── 主题设置                                                            │
│  └── 关于                                                                │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.3 Key Screens

| Screen | Purpose | Key Elements |
|--------|---------|--------------|
| **首页** | 快速概览 | 净资产、快捷操作、最近交易 |
| **交易列表** | 交易管理 | 日期分组、金额、分类图标 |
| **添加交易** | 记账入口 | 收入/支出切换、金额输入、账户选择 |
| **账户列表** | 账户管理 | 按类型分组、余额显示 |
| **导入** | 批量导入 | 文件选择、预览、映射 |
| **报表** | 数据分析 | 图表、趋势、统计 |

---

## 6. Data Requirements

### 6.1 Data Model

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DATA MODEL                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐              │
│  │ Commodity   │     │   Account   │     │  Category   │              │
│  │ ─────────── │     │ ─────────── │     │ ─────────── │              │
│  │ id          │     │ id          │     │ id          │              │
│  │ namespace   │     │ name        │     │ name        │              │
│  │ mnemonic    │     │ type        │     │ isIncome    │              │
│  │ fraction    │     │ commodity_id│────▶│ icon        │              │
│  └─────────────┘     │ parent_id   │     │ color       │              │
│          │           └──────┬──────┘     └──────┬──────┘              │
│          │                  │                   │                      │
│          │                  │                   │                      │
│          │           ┌──────▼──────┐            │                      │
│          │           │    Split    │            │                      │
│          │           │ ─────────── │            │                      │
│          │           │ id          │            │                      │
│          │           │ account_id  │◀───────────┘                      │
│          │           │ value       │                                   │
│          │           │ reconcile   │                                   │
│          │           └──────┬──────┘                                   │
│          │                  │                                          │
│          │                  │                                          │
│          │           ┌──────▼──────┐                                   │
│          └──────────▶│Transaction  │                                   │
│                      │ ─────────── │                                   │
│                      │ id          │                                   │
│                      │ description │                                   │
│                      │ post_date   │                                   │
│                      │ currency_id │                                   │
│                      │ is_double   │                                   │
│                      └─────────────┘                                   │
│                                                                          │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐              │
│  │   Budget    │     │ImportSource │     │ ImportBatch │              │
│  │ ─────────── │     │ ─────────── │     │ ─────────── │              │
│  │ id          │     │ id          │     │ id          │              │
│  │ category_id │     │ name        │     │ source_id   │              │
│  │ amount      │     │ type        │     │ record_count│              │
│  │ period      │     │ config      │     │ status      │              │
│  └─────────────┘     └─────────────┘     └─────────────┘              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Data Storage

| Data Type | Storage | Encryption |
|-----------|---------|------------|
| **用户数据** | SQLite (Drift) | SQLCipher |
| **密钥** | OS Keychain | Hardware-backed |
| **设置** | SQLite | Encrypted |
| **缓存** | Memory | N/A |

### 6.3 Data Retention

| Data Type | Retention | User Control |
|-----------|-----------|--------------|
| **交易记录** | 永久 | 可删除 |
| **账户信息** | 永久 | 可删除 |
| **导入历史** | 90天 | 可删除 |
| **日志** | 30天 | 自动清理 |

---

## 7. Integration Requirements

### 7.1 Chinese Financial Institutions

| Institution | Type | Import Method | Phase |
|-------------|------|---------------|-------|
| **支付宝** | 支付平台 | CSV导出 | 2 |
| **微信支付** | 支付平台 | CSV导出 | 2 |
| **花呗** | 信贷 | 支付宝账单 | 2 |
| **余额宝** | 理财 | 支付宝账单 | 2 |
| **零钱通** | 理财 | 微信账单 | 2 |
| **工商银行** | 银行 | CSV/网银 | 2 |
| **建设银行** | 银行 | CSV/网银 | 2 |
| **中国银行** | 银行 | CSV/网银 | 2 |
| **招商银行** | 银行 | CSV/网银 | 8 |
| **农业银行** | 银行 | CSV/网银 | 8 |

### 7.2 Import Format Support

| Format | Extension | Phase |
|--------|-----------|-------|
| **CSV** | .csv | 2 |
| **OFX** | .ofx, .qfx | 2 |
| **QIF** | .qif | 2 |
| **Excel** | .xls, .xlsx | 2 |
| **CAMT.053** | .xml | 8 |

---

## 8. Constraints & Assumptions

### 8.1 Technical Constraints

| Constraint | Impact |
|------------|--------|
| **Flutter跨平台** | 单一代码库，但需要平台特定代码 |
| **SQLite本地存储** | 数据量受设备存储限制 |
| **本地AI** | 模型大小受移动设备限制 |
| **自托管同步** | 用户需要自行部署服务器 |

### 8.2 Business Constraints

| Constraint | Impact |
|------------|--------|
| **个人开发者** | 资源有限，需优先级管理 |
| **12个月时间线** | 分阶段交付，MVP优先 |
| **无云服务** | 无服务器成本，但用户需自托管 |

### 8.3 Assumptions

| Assumption | Validation |
|------------|------------|
| 用户有基本的金融知识 | 提供引导和帮助 |
| 用户愿意自托管同步服务器 | 提供Docker一键部署 |
| 用户设备有足够存储空间 | 数据导出功能 |
| 中国金融机构不频繁更改导出格式 | 版本化解析器 |

---

## 9. Out of Scope (Must NOT Have)

### Phase 1-2

- ❌ 云端同步服务（仅自托管）
- ❌ 自动银行API同步
- ❌ 股票/基金实时行情
- ❌ 多用户协作
- ❌ 社交功能
- ❌ 广告/推荐系统

### Phase 3-5

- ❌ 云端AI处理
- ❌ 第三方数据共享
- ❌ 付费订阅功能
- ❌ 自动报税功能

### Never

- ❌ 用户行为分析/追踪
- ❌ 云端数据存储（强制）
- ❌ 第三方数据出售
- ❌ 强制账号注册

---

## 10. Success Metrics

### 10.1 Phase 1 Success Criteria

| Metric | Target | Measurement |
|--------|--------|--------------|
| **核心功能可用** | 100% | 所有CRUD操作正常 |
| **数据加密** | 100% | 所有用户数据加密 |
| **跨平台构建** | 6平台 | iOS/Android/Web/Windows/macOS/Linux |
| **测试覆盖** | >80% | 单元测试覆盖率 |

### 10.2 Phase 2 Success Criteria

| Metric | Target | Measurement |
|--------|--------|--------------|
| **导入成功率** | >95% | 成功导入/总导入 |
| **重复检测准确率** | >90% | 正确检测/总重复 |
| **支持机构数** | ≥5 | 支付宝/微信/3家银行 |

### 10.3 Overall Success Criteria

| Metric | Target | Timeframe |
|--------|--------|-----------|
| **用户留存率** | >50% | 30天 |
| **崩溃率** | <0.1% | 持续 |
| **用户满意度** | >4.0/5.0 | App Store评分 |

---

## 11. Timeline & Milestones

### 11.1 Release Roadmap

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         RELEASE ROADMAP                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  v0.1.0 (Completed) ────────────────────────────────────── 2026-05-19  │
│  ├── Project setup                                                       │
│  ├── Database layer                                                      │
│  ├── Core models                                                         │
│  ├── Encryption                                                          │
│  ├── Basic UI                                                            │
│  └── CRUD operations                                                     │
│                                                                          │
│  v0.2.0 (Phase 2) ──────────────────────────────────────── Month 3      │
│  ├── Import pipeline                                                     │
│  ├── Alipay importer                                                     │
│  ├── WeChat Pay importer                                                 │
│  └── Bank importers                                                      │
│                                                                          │
│  v0.3.0 (Phase 3) ──────────────────────────────────────── Month 4      │
│  ├── Sync server                                                         │
│  ├── PowerSync integration                                               │
│  ├── E2E encryption                                                      │
│  └── Conflict resolution                                                 │
│                                                                          │
│  v0.4.0 (Phase 4) ──────────────────────────────────────── Month 5      │
│  ├── Double-entry mode                                                   │
│  ├── Split editor                                                        │
│  └── Reconciliation                                                      │
│                                                                          │
│  v0.5.0 (Phase 5) ──────────────────────────────────────── Month 7      │
│  ├── Local AI integration                                                │
│  ├── Auto-categorization                                                 │
│  ├── NLP queries                                                         │
│  └── Spending insights                                                   │
│                                                                          │
│  v0.6.0 (Phase 6) ──────────────────────────────────────── Month 9      │
│  ├── Budget management                                                   │
│  ├── Multi-currency                                                      │
│  ├── Advanced reports                                                    │
│  └── Export functionality                                                │
│                                                                          │
│  v1.0.0 (Release) ─────────────────────────────────────── Month 12     │
│  ├── Performance optimization                                            │
│  ├── Localization                                                        │
│  ├── Security audit                                                      │
│  └── App store submission                                                │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 12. Appendices

### Appendix A: Glossary

| Term | Definition |
|------|------------|
| **本地优先** | 数据优先存储在本地设备，云端为可选 |
| **E2E加密** | 端到端加密，只有通信双方能解密 |
| **复式记账** | 每笔交易至少涉及两个账户，借贷必平衡 |
| **SQLCipher** | 加密的SQLite数据库 |
| **PowerSync** | 本地优先的同步引擎 |

### Appendix B: References

- [Implementation Plan](.sisyphus/plans/finance-app-implementation-plan.md)
- [Architecture Documentation](docs/ARCHITECTURE.md)
- [Security Guidelines](docs/SECURITY.md)
- [API Documentation](docs/API.md)

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-05-19 | Development Team | Initial PRD |