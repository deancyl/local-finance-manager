# Security & Privacy Guidelines

## Document Information

| Property | Value |
|----------|-------|
| **Version** | 1.0.0 |
| **Last Updated** | 2026-05-19 |
| **Status** | Active |
| **Applies To** | All Phases |
| **Owner** | Development Team |

---

## 1. Executive Summary

Local Finance Manager is designed with **privacy-by-design** and **security-first** principles. This document defines the security architecture, privacy protections, and compliance requirements for all development phases.

### Core Principles

1. **Local-First**: All sensitive data stored locally by default
2. **Zero Trust**: No implicit trust in any component or network
3. **Defense in Depth**: Multiple layers of security controls
4. **Data Minimization**: Collect only necessary data
5. **User Sovereignty**: User controls all data and keys

---

## 2. Threat Model

### 2.1 Threat Actors

| Actor | Capability | Motivation | Risk Level |
|-------|-------------|------------|-------------|
| **Device Thief** | Physical access to device | Financial gain | HIGH |
| **Malware** | Code execution on device | Data theft | HIGH |
| **Network Attacker** | Man-in-the-middle, interception | Credential theft | MEDIUM |
| **Cloud Provider** | Server access (sync) | Data access | MEDIUM |
| **Malicious App** | Side-loading, app store | Data exfiltration | MEDIUM |
| **Insider** | Development access | Data theft | LOW |

### 2.2 Attack Surfaces

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         ATTACK SURFACE MAP                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐              │
│  │   Device    │     │   Network   │     │   Server    │              │
│  │   Storage   │     │  Transit    │     │   (Sync)    │              │
│  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘              │
│         │                   │                   │                      │
│         ▼                   ▼                   ▼                      │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐              │
│  │ • SQLite DB │     │ • API Calls │     │ • PostgreSQL│              │
│  │ • Keychain  │     │ • Sync Data │     │ • Auth Keys │              │
│  │ • Memory    │     │ • Backups   │     │ • Logs      │              │
│  └─────────────┘     └─────────────┘     └─────────────┘              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Threat Matrix

| Threat | Likelihood | Impact | Mitigation | Phase |
|--------|------------|--------|------------|-------|
| **Device theft with unlocked app** | High | Critical | Biometric lock, auto-lock timer | 1 |
| **Database extraction from device** | Medium | Critical | SQLCipher encryption | 1 |
| **Key extraction from keychain** | Low | Critical | Hardware-backed keys | 1 |
| **Network interception** | Medium | High | TLS 1.3 + E2E encryption | 3 |
| **Sync server compromise** | Low | High | E2E encryption, zero-knowledge | 3 |
| **Malicious CSV import** | Medium | Medium | Sandboxed parsing, validation | 2 |
| **Memory dump attack** | Low | High | Secure memory handling | 1 |
| **Backup data exposure** | Medium | High | Encrypted backups | 1 |

---

## 3. Encryption Architecture

### 3.1 Key Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         KEY HIERARCHY                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Level 0: User Password (Memorized)                                    │
│           └── PBKDF2 (100,000 iterations, Argon2id recommended)        │
│                    │                                                     │
│                    ▼                                                     │
│  Level 1: Master Key (Derived)                                          │
│           └── Stored in OS Keychain                                     │
│                    │                                                     │
│                    ├──▶ Database Key (SQLCipher)                        │
│                    │    └── AES-256-GCM for SQLite                     │
│                    │                                                     │
│                    ├──▶ Sync Key (E2E)                                  │
│                    │    └── X25519 + AES-256-GCM                       │
│                    │                                                     │
│                    └──▶ Backup Key                                       │
│                         └── Paper backup / Recovery phrase              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Encryption Standards

| Layer | Algorithm | Key Size | Mode | Standard |
|-------|-----------|----------|------|----------|
| **Database** | AES-256 | 256-bit | GCM | SQLCipher 4 |
| **Sync** | AES-256 | 256-bit | GCM | E2E |
| **Key Exchange** | X25519 | 256-bit | ECDH | NaCl |
| **Signatures** | Ed25519 | 256-bit | - | NaCl |
| **Password Hashing** | Argon2id | - | - | OWASP |
| **Key Derivation** | PBKDF2 | - | SHA-256 | NIST |

### 3.3 Platform-Specific Key Storage

| Platform | Storage | Access Control | Backup |
|----------|---------|----------------|--------|
| **iOS** | Keychain Services | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` | iCloud Keychain (opt-in) |
| **Android** | Android Keystore | Biometric + PIN required | None |
| **Windows** | Credential Manager | DPAPI + Windows Hello | None |
| **macOS** | Keychain Services | Touch ID optional | iCloud Keychain (opt-in) |
| **Linux** | libsecret | Keyring | None |
| **Web** | IndexedDB + Web Crypto | Password-derived | Export required |

### 3.4 Key Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         KEY LIFECYCLE                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. CREATION                                                            │
│     ├── User sets password                                              │
│     ├── Derive Master Key (PBKDF2)                                      │
│     ├── Generate Database Key (random)                                  │
│     ├── Encrypt Database Key with Master Key                            │
│     └── Store encrypted key in keychain                                 │
│                                                                          │
│  2. USAGE                                                               │
│     ├── User unlocks (password/biometric)                               │
│     ├── Derive Master Key                                               │
│     ├── Decrypt Database Key                                            │
│     └── Open SQLCipher database                                        │
│                                                                          │
│  3. ROTATION (Manual)                                                   │
│     ├── User requests password change                                   │
│     ├── Re-encrypt Database Key with new Master Key                     │
│     └── Update keychain                                                 │
│                                                                          │
│  4. BACKUP                                                              │
│     ├── Generate recovery phrase (BIP39)                                │
│     ├── Encrypt Master Key with recovery phrase                         │
│     └── User stores paper backup                                       │
│                                                                          │
│  5. RECOVERY                                                            │
│     ├── User enters recovery phrase                                    │
│     ├── Decrypt Master Key                                              │
│     └── Restore access                                                  │
│                                                                          │
│  6. DESTRUCTION                                                         │
│     ├── Secure erase all keys                                          │
│     ├── Overwrite keychain entries                                     │
│     └── Delete database file                                           │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Data Protection

### 4.1 Data Classification

| Classification | Examples | Encryption | Access Control |
|----------------|----------|------------|-----------------|
| **Critical** | Account balances, Transaction amounts | Encrypted at rest | Biometric required |
| **Sensitive** | Account names, Categories, Payees | Encrypted at rest | Password required |
| **Internal** | Transaction dates, Settings | Encrypted at rest | App unlock |
| **Public** | App version, UI preferences | Optional | None |

### 4.2 Data at Rest

All user data stored locally MUST be encrypted:

```sql
-- SQLCipher configuration
PRAGMA key = 'derived-key';
PRAGMA cipher_page_size = 4096;
PRAGMA kdf_iter = 256000;
PRAGMA cipher_hmac_algorithm = HMAC_SHA512;
PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA512;
```

### 4.3 Data in Transit

All network communication MUST use:

1. **TLS 1.3** minimum (TLS 1.2 fallback for compatibility)
2. **Certificate pinning** for sync server
3. **E2E encryption** for all sync data
4. **No sensitive data in URLs or headers**

```
┌─────────────┐                    ┌─────────────┐
│   Client    │                    │   Server    │
│             │                    │             │
│  Encrypt    │──── TLS 1.3 ──────▶│  Decrypt    │
│  (E2E)      │                    │  (E2E)      │
│             │◀─── TLS 1.3 ──────│             │
│  Decrypt    │                    │  Encrypt    │
└─────────────┘                    └─────────────┘
```

### 4.4 Data in Memory

- **Minimize plaintext exposure**: Decrypt only when needed
- **Secure clearing**: Zero memory after use
- **No swapping**: Lock sensitive memory pages (where supported)
- **No logging**: Never log sensitive data

---

## 5. Privacy by Design

### 5.1 Data Minimization

| Data Type | Collected | Justification | Retention |
|-----------|-----------|---------------|-----------|
| Transaction amounts | ✅ Yes | Core functionality | User-controlled |
| Account names | ✅ Yes | User identification | User-controlled |
| Payee names | ✅ Yes | Transaction context | User-controlled |
| Device ID | ❌ No | Not required | N/A |
| Location | ❌ No | Not required | N/A |
| Analytics | ❌ No | Not required | N/A |
| Crash reports | ⚠️ Optional | Debugging | User opt-in |

### 5.2 User Rights (GDPR-Aligned)

| Right | Implementation |
|-------|----------------|
| **Access** | Export all data (JSON/CSV) |
| **Rectification** | Edit any data in app |
| **Erasure** | Delete account/data with confirmation |
| **Portability** | Standard format export |
| **Restriction** | Disable sync, local-only mode |
| **Object** | Disable all optional features |

### 5.3 Privacy Controls

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      PRIVACY CONTROLS                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Settings > Privacy                                                       │
│  ├── [ ] Enable sync (disabled by default)                              │
│  ├── [ ] Enable analytics (disabled by default)                         │
│  ├── [ ] Enable crash reports (disabled by default)                     │
│  ├── [ ] Enable biometric unlock                                        │
│  └── Auto-lock timer: [Immediately / 1 min / 5 min / Never]           │
│                                                                          │
│  Settings > Data                                                         │
│  ├── Export all data                                                     │
│  ├── Import data                                                         │
│  ├── Delete all data                                                    │
│  └── Generate backup key                                                │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Authentication & Authorization

### 6.1 Local Authentication

| Method | Security Level | User Experience | Required |
|--------|---------------|------------------|----------|
| **Password** | High | Medium | Yes (initial) |
| **Biometric** | High | Excellent | Optional |
| **PIN** | Medium | Excellent | Optional |

### 6.2 Authentication Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    AUTHENTICATION FLOW                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  App Start                                                               │
│      │                                                                    │
│      ▼                                                                    │
│  ┌─────────────┐                                                         │
│  │ Biometric  │── Available? ── Yes ──▶ Prompt biometric               │
│  │ Enabled?   │                                                          │
│  └──────┬──────┘                                                         │
│         │ No                                                             │
│         ▼                                                                │
│  ┌─────────────┐                                                         │
│  │ Password    │── Prompt password                                       │
│  │ Prompt      │                                                          │
│  └──────┬──────┘                                                         │
│         │                                                                │
│         ▼                                                                │
│  ┌─────────────┐                                                         │
│  │ Derive Key  │── PBKDF2 from password                                  │
│  └──────┬──────┘                                                         │
│         │                                                                │
│         ▼                                                                │
│  ┌─────────────┐                                                         │
│  │ Decrypt DB  │── Open SQLCipher                                        │
│  │ Key         │                                                          │
│  └──────┬──────┘                                                         │
│         │                                                                │
│         ▼                                                                │
│  App Ready                                                               │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 6.3 Session Management

| Setting | Default | Range | Phase |
|---------|---------|-------|-------|
| **Auto-lock timer** | 5 minutes | 1-30 min, Never | 1 |
| **Failed attempt limit** | 10 | 5-20 | 1 |
| **Lockout duration** | 1 minute | 1-30 min | 1 |
| **Biometric timeout** | 30 seconds | 10-120 sec | 1 |

---

## 7. Secure Development Practices

### 7.1 Code Security

| Practice | Requirement | Verification |
|----------|-------------|---------------|
| **No hardcoded secrets** | Zero tolerance | Automated scan |
| **Input validation** | All external inputs | Code review |
| **Output encoding** | All user-generated content | Code review |
| **Error handling** | No sensitive data in errors | Code review |
| **Logging** | No PII in logs | Automated scan |
| **Dependencies** | Minimal, audited | `flutter pub outdated` |

### 7.2 Security Code Review Checklist

```markdown
## Pre-Merge Security Checklist

- [ ] No hardcoded credentials or keys
- [ ] All user inputs validated and sanitized
- [ ] All file operations use secure paths
- [ ] No sensitive data in logs or errors
- [ ] Encryption used for sensitive data
- [ ] Keys stored in keychain, not preferences
- [ ] Network calls use TLS 1.2+
- [ ] No insecure dependencies
- [ ] Memory cleared after sensitive operations
- [ ] Biometric fallback to password implemented
```

### 7.3 Dependency Security

```yaml
# pubspec.yaml security requirements
dependencies:
  # Only use packages with:
  # - Active maintenance (updated within 6 months)
  # - High popularity (100+ likes)
  # - No known vulnerabilities
  
dev_dependencies:
  # Security scanning tools
  dependency_validator: ^4.0.0
```

---

## 8. Incident Response

### 8.1 Security Incident Categories

| Category | Examples | Severity | Response Time |
|----------|----------|----------|---------------|
| **Critical** | Key compromise, Data breach | P0 | Immediate |
| **High** | Vulnerability disclosure, Auth bypass | P1 | 24 hours |
| **Medium** | Data exposure, Misconfiguration | P2 | 72 hours |
| **Low** | Security warning, Best practice violation | P3 | 1 week |

### 8.2 Incident Response Procedure

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    INCIDENT RESPONSE                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. DETECT                                                               │
│     ├── User report                                                      │
│     ├── Security audit                                                   │
│     └── Automated monitoring                                             │
│                                                                          │
│  2. ASSESS                                                               │
│     ├── Classify severity                                                │
│     ├── Determine scope                                                  │
│     └── Identify affected users                                          │
│                                                                          │
│  3. CONTAIN                                                              │
│     ├── Disable affected features                                        │
│     ├── Revoke compromised keys                                          │
│     └── Isolate affected systems                                         │
│                                                                          │
│  4. REMEDIATE                                                            │
│     ├── Fix vulnerability                                                │
│     ├── Patch and release                                                │
│     └── Update documentation                                             │
│                                                                          │
│  5. RECOVER                                                              │
│     ├── Restore services                                                 │
│     ├── Notify affected users                                           │
│     └── Update security measures                                        │
│                                                                          │
│  6. REVIEW                                                               │
│     ├── Post-incident analysis                                           │
│     ├── Update procedures                                                │
│     └── Implement preventive measures                                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 8.3 Key Compromise Response

If encryption keys are compromised:

1. **Immediate**: Disable sync functionality
2. **User notification**: Alert all users to change password
3. **Key rotation**: Force re-encryption with new keys
4. **Audit**: Review all data access logs
5. **Document**: Record incident details and lessons learned

---

## 9. Compliance Requirements

### 9.1 App Store Requirements

| Requirement | iOS | Android | Implementation |
|-------------|-----|---------|----------------|
| **Privacy Policy** | Required | Required | `docs/PRIVACY_POLICY.md` |
| **Data Disclosure** | Required | Required | App Store Connect |
| **Encryption Export** | Required | Required | App submission |
| **App Transport Security** | Required | N/A | Info.plist |
| **Network Security Config** | N/A | Required | network_security_config.xml |

### 9.2 Chinese Regulations

| Regulation | Requirement | Implementation |
|------------|-------------|----------------|
| **Cybersecurity Law** | Data localization | Local-first, optional sync |
| **Personal Information Protection Law** | Consent, minimization | Privacy controls, export |
| **Data Security Law** | Classification | Data classification system |

### 9.3 International Standards

| Standard | Compliance | Evidence |
|----------|------------|----------|
| **OWASP MASVS** | Level 1 | Security testing |
| **GDPR** | Aligned | Privacy controls |
| **CCPA** | Aligned | Data export |

---

## 10. Security Testing

### 10.1 Required Security Tests

| Test Type | Frequency | Tool | Phase |
|-----------|-----------|------|-------|
| **Static Analysis** | Every commit | `flutter analyze` | 1+ |
| **Dependency Scan** | Weekly | `flutter pub outdated` | 1+ |
| **Penetration Test** | Before release | Manual + automated | 3+ |
| **Encryption Test** | Every release | Unit tests | 1+ |
| **Authentication Test** | Every release | Unit tests | 1+ |

### 10.2 Security Test Commands

```bash
# Run security-focused tests
flutter test test/security/

# Verify encryption
flutter test test/security/encryption_test.dart

# Verify authentication
flutter test test/security/authentication_test.dart

# Verify key storage
flutter test test/security/keychain_test.dart

# Static analysis
flutter analyze --no-fatal-infos

# Dependency audit
flutter pub outdated --no-dev-dependencies
```

### 10.3 Security Test Coverage

| Component | Coverage Target | Current |
|-----------|-----------------|---------|
| Encryption service | 100% | TBD |
| Keychain service | 100% | TBD |
| Authentication flow | 100% | TBD |
| Data validation | 90% | TBD |
| Network security | 80% | TBD |

---

## 11. Security Checklist by Phase

### Phase 1: Foundation ✅

- [x] SQLCipher database encryption
- [x] OS Keychain integration
- [x] AES-256-GCM encryption service
- [x] Password hashing (PBKDF2)
- [x] Secure random key generation

### Phase 2: Import System

- [ ] CSV parsing sandboxing
- [ ] File type validation
- [ ] Import size limits
- [ ] Memory clearing after parse
- [ ] No code execution from imports

### Phase 3: Sync System

- [ ] TLS 1.3 enforcement
- [ ] Certificate pinning
- [ ] E2E encryption for sync
- [ ] Key rotation support
- [ ] Secure key exchange (X25519)

### Phase 4: Double-Entry

- [ ] Transaction validation
- [ ] Balance verification
- [ ] Audit trail integrity
- [ ] Reconciliation security

### Phase 5: AI Integration

- [ ] PII masking before AI
- [ ] Local-only processing
- [ ] No cloud AI fallback
- [ ] Model sandboxing

### Phase 6: Advanced Features

- [ ] Secure backup encryption
- [ ] Export data sanitization
- [ ] Multi-currency validation
- [ ] Report data protection

---

## 12. Security Contact

For security concerns or vulnerability reports:

- **Email**: security@localfinance.example.com (placeholder)
- **Response Time**: 48 hours maximum
- **Disclosure Policy**: Coordinated disclosure after fix

---

## Appendix A: Security Configuration Reference

### iOS (Info.plist)

```xml
<key>NSFaceIDUsageDescription</key>
<string>Local Finance Manager uses Face ID to securely unlock your financial data.</string>

<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>sync.localfinance.example.com</key>
        <dict>
            <key>NSExceptionRequiresForwardSecrecy</key>
            <true/>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.3</string>
        </dict>
    </dict>
</dict>
```

### Android (network_security_config.xml)

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config>
        <domain includeSubdomains="true">sync.localfinance.example.com</domain>
        <pin-set>
            <pin digest="SHA-256">base64-encoded-pin</pin>
        </pin-set>
        <trust-anchors>
            <certificates src="@raw/sync_cert"/>
        </trust-anchors>
    </domain-config>
</network-security-config>
```

---

## Appendix B: Security Audit Log Template

```markdown
## Security Audit Log

**Date**: YYYY-MM-DD
**Auditor**: [Name]
**Version**: vX.Y.Z

### Findings

| ID | Severity | Description | Status | Resolution |
|----|----------|-------------|--------|------------|
| S1 | High | [Description] | Open | [Planned fix] |

### Recommendations

1. [Recommendation 1]
2. [Recommendation 2]

### Next Audit

Scheduled: YYYY-MM-DD
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-05-19 | Initial security guidelines |