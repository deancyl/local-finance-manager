/// Accounting terminology glossary for user education.
///
/// Provides simple, accessible explanations for accounting terms
/// in both Chinese and English to help users understand complex
/// financial concepts.

/// A single glossary entry explaining an accounting term.
class GlossaryEntry {
  /// The term key (e.g., 'debit', 'asset')
  final String key;
  
  /// Chinese name of the term
  final String nameZh;
  
  /// English name of the term
  final String nameEn;
  
  /// Simple explanation in Chinese (user-friendly)
  final String explanationZh;
  
  /// Simple explanation in English (user-friendly)
  final String explanationEn;
  
  /// More detailed explanation in Chinese (for tooltip expansion)
  final String? detailZh;
  
  /// More detailed explanation in English (for tooltip expansion)
  final String? detailEn;
  
  /// Icon to display alongside the term
  final IconDataData iconData;
  
  /// Color for the icon (hex string)
  final String iconColor;

  const GlossaryEntry({
    required this.key,
    required this.nameZh,
    required this.nameEn,
    required this.explanationZh,
    required this.explanationEn,
    this.detailZh,
    this.detailEn,
    required this.iconData,
    required this.iconColor,
  });
}

/// Icon data representation for cross-platform compatibility.
class IconDataData {
  final String name;
  final int codePoint;

  const IconDataData({
    required this.name,
    required this.codePoint,
  });
}

/// Central glossary of accounting terminology.
///
/// Terms are organized by category:
/// - Core concepts (debit/credit)
/// - Account types (asset/liability/equity/income/expense)
class AccountingGlossary {
  /// Get all glossary entries.
  static const List<GlossaryEntry> all = [
    // Core Debit/Credit Concepts
    debitEntry,
    creditEntry,
    
    // Account Types
    assetEntry,
    liabilityEntry,
    equityEntry,
    incomeEntry,
    expenseEntry,
  ];

  /// Debit (借方) - Left side of accounting entry.
  static const debitEntry = GlossaryEntry(
    key: 'debit',
    nameZh: '借方',
    nameEn: 'Debit',
    explanationZh: '资产和费用的增加，或负债、权益、收入的减少',
    explanationEn: 'Increase in assets/expenses, or decrease in liabilities/equity/income',
    detailZh: '在复式记账中，借方记录在左侧。资产类账户（如现金、银行存款）增加时记借方，减少时记贷方。',
    detailEn: 'In double-entry bookkeeping, debits are recorded on the left side. Asset accounts increase on the debit side and decrease on the credit side.',
    iconData: IconDataData(name: 'arrow_forward', codePoint: 0xe5c8),
    iconColor: '#FF9800', // Orange
  );

  /// Credit (贷方) - Right side of accounting entry.
  static const creditEntry = GlossaryEntry(
    key: 'credit',
    nameZh: '贷方',
    nameEn: 'Credit',
    explanationZh: '负债、权益、收入的增加，或资产和费用的减少',
    explanationEn: 'Increase in liabilities/equity/income, or decrease in assets/expenses',
    detailZh: '在复式记账中，贷方记录在右侧。负债类账户（如贷款、信用卡）增加时记贷方，减少时记借方。',
    detailEn: 'In double-entry bookkeeping, credits are recorded on the right side. Liability accounts increase on the credit side and decrease on the debit side.',
    iconData: IconDataData(name: 'arrow_back', codePoint: 0xe5c4),
    iconColor: '#2196F3', // Blue
  );

  /// Asset (资产) - Things you own.
  static const assetEntry = GlossaryEntry(
    key: 'asset',
    nameZh: '资产',
    nameEn: 'Asset',
    explanationZh: '你拥有的东西（现金、银行存款、房产）',
    explanationEn: 'Things you own (cash, bank deposits, property)',
    detailZh: '资产是企业或个人拥有的、能带来未来经济利益的资源。包括流动资产（现金、银行存款）和固定资产（房产、设备）。',
    detailEn: 'Assets are resources owned by a business or individual that can bring future economic benefits. Includes current assets (cash, bank deposits) and fixed assets (property, equipment).',
    iconData: IconDataData(name: 'account_balance_wallet', codePoint: 0xe190),
    iconColor: '#4CAF50', // Green
  );

  /// Liability (负债) - Things you owe.
  static const liabilityEntry = GlossaryEntry(
    key: 'liability',
    nameZh: '负债',
    nameEn: 'Liability',
    explanationZh: '你欠别人的钱（信用卡、贷款）',
    explanationEn: 'Money you owe others (credit cards, loans)',
    detailZh: '负债是企业或个人需要偿还的债务。包括短期负债（信用卡账单）和长期负债（房贷、车贷）。',
    detailEn: 'Liabilities are debts that a business or individual needs to repay. Includes short-term liabilities (credit card bills) and long-term liabilities (mortgages, car loans).',
    iconData: IconDataData(name: 'credit_card', codePoint: 0xe8a1),
    iconColor: '#F44336', // Red
  );

  /// Equity (权益) - Your net worth.
  static const equityEntry = GlossaryEntry(
    key: 'equity',
    nameZh: '权益',
    nameEn: 'Equity',
    explanationZh: '你的净资产（资产 - 负债）',
    explanationEn: 'Your net worth (assets - liabilities)',
    detailZh: '权益代表所有者在企业或个人资产中的剩余权益。公式：权益 = 资产 - 负债。包括初始投入资本和累计盈余。',
    detailEn: 'Equity represents the owner\'s residual interest in business or personal assets. Formula: Equity = Assets - Liabilities. Includes initial capital investment and accumulated surplus.',
    iconData: IconDataData(name: 'pie_chart', codePoint: 0xe569),
    iconColor: '#9C27B0', // Purple
  );

  /// Income (收入) - Money you earn.
  static const incomeEntry = GlossaryEntry(
    key: 'income',
    nameZh: '收入',
    nameEn: 'Income',
    explanationZh: '你赚到的钱',
    explanationEn: 'Money you earn',
    detailZh: '收入是通过经营活动或投资获得的资金流入。包括工资收入、经营收入、投资收益等。',
    detailEn: 'Income is funds received through business activities or investments. Includes salary income, business income, investment returns, etc.',
    iconData: IconDataData(name: 'trending_up', codePoint: 0xe8e5),
    iconColor: '#2196F3', // Blue
  );

  /// Expense (费用) - Money you spend.
  static const expenseEntry = GlossaryEntry(
    key: 'expense',
    nameZh: '费用',
    nameEn: 'Expense',
    explanationZh: '你花出去的钱',
    explanationEn: 'Money you spend',
    detailZh: '费用是为获取收入而产生的资金流出。包括日常消费、经营成本、税费等。',
    detailEn: 'Expenses are funds spent to generate income. Includes daily consumption, business costs, taxes, etc.',
    iconData: IconDataData(name: 'shopping_cart', codePoint: 0xe8cc),
    iconColor: '#FF9800', // Orange
  );

  /// Get glossary entry by key.
  static GlossaryEntry? getByKey(String key) {
    try {
      return all.firstWhere((entry) => entry.key == key);
    } catch (_) {
      return null;
    }
  }

  /// Get glossary entry by account type.
  static GlossaryEntry? getByAccountType(String accountType) {
    final key = accountType.toLowerCase();
    return getByKey(key);
  }

  /// Get Chinese name for account type.
  static String getNameZh(String accountType) {
    final entry = getByAccountType(accountType);
    return entry?.nameZh ?? accountType;
  }

  /// Get English name for account type.
  static String getNameEn(String accountType) {
    final entry = getByAccountType(accountType);
    return entry?.nameEn ?? accountType;
  }
}