# Privacy Policy / 隐私政策

**Last Updated / 最后更新**: 2026-05-19  
**Version / 版本**: 1.0.0  
**Language / 语言**: English / 中文

---

## English Version

### 1. Introduction

**Local Finance Manager** ("we", "our", or "the App") is committed to protecting your privacy. This Privacy Policy explains how our application handles your information.

**Key Principle**: Local Finance Manager is a **local-first** application. By default, all your data stays on your device and is encrypted. We do not collect, transmit, or store your personal financial data on our servers.

### 2. Data Storage

#### 2.1 Local Storage

All user data is stored locally on your device using encrypted SQLite databases (SQLCipher with AES-256-GCM encryption). This includes:

- Account information and balances
- Transaction records
- Categories and budgets
- Import history
- App settings

#### 2.2 Encryption

All sensitive data is encrypted at rest using:

- **Database Encryption**: SQLCipher with AES-256-GCM
- **Key Storage**: Operating system keychain (iOS Keychain, Android Keystore, Windows Credential Manager, macOS Keychain, Linux libsecret)
- **Password Protection**: PBKDF2/Argon2id key derivation

### 3. Data Collection

#### 3.1 What We Do NOT Collect

We do **NOT** collect:

- ❌ Personal identification information
- ❌ Financial data (transactions, balances, accounts)
- ❌ Location data
- ❌ Device identifiers
- ❌ Usage analytics
- ❌ Crash reports (unless you opt-in)
- ❌ Advertising identifiers

#### 3.2 Optional Data (User Opt-In)

| Data Type | Purpose | Default | Opt-In Required |
|-----------|---------|---------|-----------------|
| Crash reports | Debug and improve app stability | OFF | Yes |
| Sync data | Multi-device synchronization | OFF | Yes (requires self-hosted server) |

### 4. Data Sync (Optional Feature)

#### 4.1 Self-Hosted Sync

If you choose to enable sync:

1. **You control the server**: You deploy and operate your own sync server
2. **End-to-end encryption**: All sync data is encrypted before transmission
3. **Zero-knowledge**: We cannot access your sync data even if you use our reference server implementation
4. **No cloud dependency**: The app works fully without sync enabled

#### 4.2 Sync Data Transmission

When sync is enabled:

- Data is encrypted on your device using AES-256-GCM
- Transmission uses TLS 1.3
- Your sync server stores only encrypted data
- Keys never leave your device

### 5. Third-Party Services

#### 5.1 No Third-Party Analytics

We do not use any third-party analytics services (Google Analytics, Firebase Analytics, etc.).

#### 5.2 No Third-Party Advertising

We do not display advertisements or use advertising SDKs.

#### 5.3 AI Features (Optional)

If you enable local AI features:

- AI processing happens entirely on your device
- No data is sent to cloud AI services
- You can disable AI features at any time
- The app works fully without AI features

### 6. Data Import

#### 6.1 Financial Institution Data

When you import data from financial institutions (Alipay, WeChat Pay, banks):

- Import files are processed locally on your device
- Files are not uploaded to any server
- Imported data is stored in your encrypted local database
- You can delete import files after processing

### 7. Data Export and Deletion

#### 7.1 Your Rights

You have complete control over your data:

| Right | How to Exercise |
|-------|-----------------|
| **Access** | Export all data via Settings > Data > Export |
| **Portability** | Export in JSON or CSV format |
| **Deletion** | Settings > Data > Delete All Data |
| **Correction** | Edit any data directly in the app |

#### 7.2 Complete Deletion

To completely delete all data:

1. Open Settings > Data
2. Tap "Delete All Data"
3. Confirm deletion
4. Optionally, uninstall the app

### 8. Security Measures

#### 8.1 Technical Safeguards

| Measure | Implementation |
|---------|----------------|
| **Encryption at Rest** | AES-256-GCM via SQLCipher |
| **Encryption in Transit** | TLS 1.3 + E2E encryption |
| **Key Protection** | Hardware-backed keychain storage |
| **Authentication** | Password + optional biometric |
| **Auto-lock** | Configurable timer (default: 5 minutes) |

#### 8.2 Security Best Practices

- Use a strong password
- Enable biometric unlock for convenience
- Enable auto-lock
- Keep your device operating system updated
- Do not share your password or recovery phrase

### 9. Children's Privacy

This app is not intended for children under 13. We do not knowingly collect any information from children.

### 10. International Users

#### 10.1 Data Localization

All data is stored locally on your device by default. No data crosses borders unless you explicitly enable sync.

#### 10.2 Regulatory Compliance

| Regulation | Compliance |
|------------|------------|
| **GDPR** | Full local control, export, and deletion rights |
| **CCPA** | No data sale, full access and deletion rights |
| **Chinese PIPL** | Local-first storage, explicit consent for sync |
| **Chinese Data Security Law** | User-controlled data classification |

### 11. Changes to This Policy

We may update this Privacy Policy from time to time. We will notify you of any changes by:

- Updating the "Last Updated" date
- Displaying an in-app notification for significant changes

### 12. Contact Us

For privacy-related questions:

- **GitHub Issues**: https://github.com/deancyl/local-finance-manager/issues
- **Response Time**: Within 7 business days

---

## 中文版本

### 1. 简介

**本地金融管家**（以下简称"我们"或"本应用"）致力于保护您的隐私。本隐私政策说明我们的应用程序如何处理您的信息。

**核心原则**：本地金融管家是一款**本地优先**的应用程序。默认情况下，您的所有数据都保存在您的设备上并经过加密。我们不会收集、传输或在我们的服务器上存储您的个人财务数据。

### 2. 数据存储

#### 2.1 本地存储

所有用户数据使用加密的SQLite数据库存储在您的设备本地（使用SQLCipher和AES-256-GCM加密）。这包括：

- 账户信息和余额
- 交易记录
- 分类和预算
- 导入历史
- 应用设置

#### 2.2 加密

所有敏感数据在静态存储时均经过加密：

- **数据库加密**：SQLCipher with AES-256-GCM
- **密钥存储**：操作系统密钥链（iOS Keychain、Android Keystore、Windows凭据管理器、macOS Keychain、Linux libsecret）
- **密码保护**：PBKDF2/Argon2id密钥派生

### 3. 数据收集

#### 3.1 我们不收集的数据

我们**不**收集：

- ❌ 个人身份信息
- ❌ 财务数据（交易、余额、账户）
- ❌ 位置数据
- ❌ 设备标识符
- ❌ 使用分析
- ❌ 崩溃报告（除非您选择加入）
- ❌ 广告标识符

#### 3.2 可选数据（用户选择加入）

| 数据类型 | 用途 | 默认状态 | 需要选择加入 |
|-----------|---------|---------|-----------------|
| 崩溃报告 | 调试和改进应用稳定性 | 关闭 | 是 |
| 同步数据 | 多设备同步 | 关闭 | 是（需要自托管服务器） |

### 4. 数据同步（可选功能）

#### 4.1 自托管同步

如果您选择启用同步：

1. **您控制服务器**：您部署和运营自己的同步服务器
2. **端到端加密**：所有同步数据在传输前已加密
3. **零知识**：即使您使用我们的参考服务器实现，我们也无法访问您的同步数据
4. **无云依赖**：应用在未启用同步时完全可用

#### 4.2 同步数据传输

启用同步时：

- 数据在您的设备上使用AES-256-GCM加密
- 传输使用TLS 1.3
- 您的同步服务器仅存储加密数据
- 密钥永不离开您的设备

### 5. 第三方服务

#### 5.1 无第三方分析

我们不使用任何第三方分析服务（Google Analytics、Firebase Analytics等）。

#### 5.2 无第三方广告

我们不展示广告或使用广告SDK。

#### 5.3 AI功能（可选）

如果您启用本地AI功能：

- AI处理完全在您的设备上进行
- 不向云端AI服务发送任何数据
- 您可以随时禁用AI功能
- 应用在没有AI功能时完全可用

### 6. 数据导入

#### 6.1 金融机构数据

当您从金融机构（支付宝、微信支付、银行）导入数据时：

- 导入文件在您的设备本地处理
- 文件不会上传到任何服务器
- 导入的数据存储在您的加密本地数据库中
- 您可以在处理后删除导入文件

### 7. 数据导出和删除

#### 7.1 您的权利

您对您的数据拥有完全控制权：

| 权利 | 如何行使 |
|-------|-----------------|
| **访问** | 通过设置 > 数据 > 导出导出所有数据 |
| **可携带性** | 以JSON或CSV格式导出 |
| **删除** | 设置 > 数据 > 删除所有数据 |
| **更正** | 直接在应用中编辑任何数据 |

#### 7.2 完全删除

要完全删除所有数据：

1. 打开设置 > 数据
2. 点击"删除所有数据"
3. 确认删除
4. 可选择卸载应用

### 8. 安全措施

#### 8.1 技术保障

| 措施 | 实现 |
|---------|----------------|
| **静态加密** | SQLCipher的AES-256-GCM |
| **传输加密** | TLS 1.3 + 端到端加密 |
| **密钥保护** | 硬件支持的密钥链存储 |
| **身份验证** | 密码 + 可选生物识别 |
| **自动锁定** | 可配置计时器（默认：5分钟） |

#### 8.2 安全最佳实践

- 使用强密码
- 启用生物识别解锁以方便使用
- 启用自动锁定
- 保持设备操作系统更新
- 不要分享您的密码或恢复短语

### 9. 儿童隐私

本应用不面向13岁以下儿童。我们不会故意收集儿童的任何信息。

### 10. 国际用户

#### 10.1 数据本地化

默认情况下，所有数据存储在您的设备本地。除非您明确启用同步，否则数据不会跨境传输。

#### 10.2 法规合规

| 法规 | 合规状态 |
|------------|------------|
| **GDPR** | 完全本地控制、导出和删除权利 |
| **CCPA** | 不出售数据、完全访问和删除权利 |
| **中国个人信息保护法** | 本地优先存储、同步需明确同意 |
| **中国数据安全法** | 用户控制的数据分类 |

### 11. 本政策变更

我们可能会不时更新本隐私政策。我们将通过以下方式通知您任何变更：

- 更新"最后更新"日期
- 在应用内显示重大变更通知

### 12. 联系我们

如有隐私相关问题：

- **GitHub Issues**: https://github.com/deancyl/local-finance-manager/issues
- **响应时间**: 7个工作日内

---

## Version History / 版本历史

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-05-19 | Initial privacy policy / 初始隐私政策 |
