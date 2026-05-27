# Release Notes - v0.3.160

## Overview

**Version**: 0.3.160  
**Release Date**: 2026-05-27  
**Type**: Release Candidate (RC)

This release marks the completion of the v0.3.156-160 development cycle, focusing on preparation, documentation, and testing infrastructure.

## Release Summary

### v0.3.156: PowerSync Re-integration Prep
- PowerSync re-integration plan documentation
- Flutter 3.29+ compatibility requirements documented
- Sync module structure prepared for future upgrade

### v0.3.157: Performance Profiling Tools
- Performance profiling configuration and documentation
- Flutter DevTools profiling workflow
- Database query profiling setup
- Performance baseline documentation

### v0.3.158: Documentation Update
- README.md comprehensive updates
- Roadmap updated with all completed milestones
- Android 15+ compliance achievements documented

### v0.3.159: Integration Testing
- Comprehensive testing strategy documentation
- Test coverage targets defined
- CI integration configuration
- Release criteria checklist

### v0.3.160: Final Release
- Version numbering finalized
- Release notes documentation
- All versions published and tagged

## Key Features (Cumulative)

### Android 15+ Compliance (v0.3.144)
- Flutter 3.32.0 upgrade
- AGP 8.5.2 upgrade
- Kotlin 2.0.21 upgrade
- 16KB ELF alignment verification script

### Double-Entry Bookkeeping (v0.3.131-135)
- Journal entries support
- Trial balance from journal entries
- Balance sheet from journal entries
- Account type hierarchy

### AI Integration (v0.3.136-140)
- Ollama local LLM integration
- Spending insights and analysis
- Category suggestions
- Budget recommendations
- Anomaly detection

### Investment Tracking (v0.3.107)
- Investment holdings management
- Investment transactions (buy/sell/dividend)
- Portfolio performance metrics
- FIFO realized gains calculation

### Export Formats (v0.3.117)
- Excel (XLSX) export
- Enhanced PDF reports
- Custom CSV export
- QIF export improvements

### Multi-Currency (v0.3.44)
- Exchange rates management
- Currency conversion
- Multiple rate sources

### Recurring Transactions (v0.3.19)
- Scheduled transaction templates
- Auto-generation from templates
- Frequency support (daily/weekly/monthly/yearly)

### Budget Management (v0.3.18)
- Budget tracking with progress indicators
- Category-based budgets
- Period selector (monthly/yearly/custom)
- Over-budget warnings

### Transaction Tags (v0.3.17)
- Tag management (create/edit/delete)
- Color picker
- Multi-select tags
- Filter by tag

### Dark Mode (v0.3.16)
- Material 3 dark theme
- System/light/dark options
- Theme persistence

### Pagination & Filtering (v0.3.15)
- Infinite scroll (20 per page)
- Pull-to-refresh
- Database-level filtering
- Chart drill-down

### Account Hierarchy (v0.3.8)
- Account groups (placeholders)
- Parent-child relationships
- Tree view with expand/collapse
- Subtotal calculation

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Android | ✅ Stable | 16KB alignment compliant for Android 15+ |
| iOS | ✅ Stable | Standard Flutter support |
| Web | ✅ Beta | Works with SQLite WASM |
| Windows | ⚠️ Alpha | Basic functionality |
| macOS | ⚠️ Alpha | Basic functionality |
| Linux | ⚠️ Alpha | Basic functionality |

## Known Issues

1. **Sync Feature**: Temporarily disabled due to PowerSync API compatibility
   - Planned re-integration in future release
   - See `docs/powersync-reintegration-plan.md`

2. **Windows Build**: Optimization pending
   - Basic functionality works
   - Performance optimization planned

3. **Test Suite**: Some tests disabled during upgrades
   - Restoration planned in next cycle

## Next Steps

### Planned for v0.3.161+
- PowerSync full re-integration
- WebSocket real-time sync
- QR code device pairing
- Sync status indicator
- Offline queue visualization
- Multi-device sync testing

### Planned for v0.4.0
- Full double-entry bookkeeping
- Trial balance report
- Balance sheet report
- Income statement report
- Journal entry editor enhancements

## Upgrade Instructions

### From v0.3.144 to v0.3.160

1. Pull latest code:
   ```bash
   git pull origin main
   git checkout v0.3.160
   ```

2. Update dependencies:
   ```bash
   flutter pub get
   melos bootstrap
   ```

3. Run database migrations (automatic on app launch)

4. Verify functionality:
   - Test transaction CRUD
   - Test import functions
   - Test budget tracking
   - Test report generation

## Download Links

- GitHub Release: https://github.com/deancyl/local-finance-manager/releases/tag/v0.3.160
- APK (when available): Check GitHub releases
- Source Code: Available on GitHub

## Contributors

- Development: Sisyphus Labs AI Agent
- Documentation: AI-assisted generation
- Testing: Automated test suite

## License

MIT License - See LICENSE file for details

---

**Full Changelog**: See CHANGELOG.md for detailed version history.