# Test Investigation Report - v0.3.146

**Investigation Date:** 2026-05-27  
**Version Context:** v0.3.145 → v0.3.146  
**Issue:** Tests disabled in CI workflow (test.yml)

---

## Executive Summary

Tests in CI were disabled due to pre-existing test failures. The primary cause is the **PowerSync dependency being temporarily disabled**.

**Status:** Investigation complete  
**Root Cause:** PowerSync package dependency commented out in `packages/sync/pubspec.yaml`

---

## Root Cause Analysis

### Primary Cause: PowerSync Dependency Disabled

```yaml
dependencies:
  # powersync: ^1.9.0  # Temporarily disabled
```

**Impact:**
- Sync package tests cannot compile/run
- Tests importing sync package fail

---

## Test Failure Categories

| Package | Test Files | Expected Status |
|---------|------------|-----------------|
| sync | 8 | ❌ Fail |
| sync_server | 4 | ⚠️ May fail |
| mobile | 6 | ⚠️ Mixed |
| core | 3 | ✅ Should pass |
| importers | 4 | ✅ Should pass |
| encryption | 1 | ✅ Should pass |
| ai | 1 | ✅ Should pass |

---

## Resolution for v0.3.147

Update test.yml to run non-sync tests only.

---

*Document generated: 2026-05-27*