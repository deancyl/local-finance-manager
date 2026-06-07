# Top 30 关键改进清单 (Critical Improvement Roadmap)

**生成日期**: 2026-06-08  
**审计版本**: v0.3.231  
**问题总数**: 89个  
**Top 30筛选标准**: 按严重程度+影响范围+修复难度综合排序

---

## 🔥 P0 - 本周必须修复 (10个)

### 1. 🔴 数据库连接泄漏 - 后台任务崩溃风险
**严重程度**: Critical  
**问题位置**: `apps/mobile/lib/features/recurring/data/background_recurring_processor.dart:38-71`

**问题描述**:
```dart
Future<void> _processRecurringTransactions() async {
  final db = await _openDatabase();
  // ... 多个early return路径
  for (final recurring in dueTransactions) {
    try {
      // ... 可能抛异常
    } catch (e) {
      debugPrint('...');  // ❌ 异常后没有关闭数据库
    }
  }
  await db.close();  // 可能永远无法到达
}
```

**影响分析**:
- 后台定期交易生成任务失败
- 数据库连接泄漏，长期运行后耗尽连接池
- 应用响应缓慢甚至崩溃

**修复方案**:
```dart
Future<void> _processRecurringTransactions() async {
  final db = await _openDatabase();
  try {
    // ... 处理逻辑
  } finally {
    await db.close();  // ✅ 确保关闭
  }
}
```

**验证方法**: 压力测试后台任务，模拟异常场景

---

### 2. 🔴 并发安全问题 - SharedPreferences竞态条件
**严重程度**: Critical  
**问题位置**: `apps/mobile/lib/features/budgets/data/budget_notification_service.dart:131-160`

**问题描述**:
```dart
final prefs = await SharedPreferences.getInstance();
final triggeredAlerts = prefs.getStringList(triggeredKey) ?? [];

// ❌ 非原子操作 - 多个进程可能同时检查和设置
if (triggeredAlerts.contains(threshold.toString())) continue;
triggeredAlerts.add(threshold.toString());
await prefs.setStringList(triggeredKey, triggeredAlerts);
```

**影响分析**:
- 预算提醒重复发送，打扰用户
- 或提醒丢失，用户错过重要通知
- 后台任务与前台UI并发访问冲突

**修复方案**:
```dart
// 方案1: 使用锁机制
final lock = Lock();
await lock.synchronized(() async {
  final prefs = await SharedPreferences.getInstance();
  // ... 原子操作
});

// 方案2: 使用一次性读取-写入
final prefs = await SharedPreferences.getInstance();
final triggeredAlerts = Set<String>.from(prefs.getStringList(triggeredKey) ?? []);
// 修改后一次性写入
await prefs.setStringList(triggeredKey, triggeredAlerts.toList());
```

**验证方法**: 并发测试，模拟多进程同时触发

---

### 3. 🔴 定期交易生成无事务保护 - 数据不一致
**严重程度**: Critical  
**问题位置**: `packages/database/lib/src/daos/recurring_dao.dart:76-153`

**问题描述**:
```dart
Future<String> generateTransaction(String recurringId) async {
  // ❌ 没有使用transaction()包裹
  await batch((b) {
    b.insert(transactions, transaction);
    b.insert(splits, split);
  });
  
  await (update(recurringTransactions)...)  // ❌ 分开的两步操作
```

**影响分析**:
- 在transaction和recurring update之间崩溃
- 交易已创建但recurring记录未更新
- 下次运行会重复创建相同交易

**修复方案**:
```dart
Future<String> generateTransaction(String recurringId) async {
  return await transaction(() async {
    // ✅ 在同一个事务中完成所有操作
    await batch((b) {
      b.insert(transactions, transaction);
      b.insert(splits, split);
    });
    
    await (update(recurringTransactions)...).go();
    return transactionId;
  });
}
```

**验证方法**: 模拟崩溃场景，验证数据一致性

---

### 4. 🔴 JSON解析未验证类型 - 模板功能崩溃
**严重程度**: Critical  
**问题位置**: `apps/mobile/lib/features/templates/data/template_provider.dart:76-80`

**问题描述**:
```dart
factory TemplateModel.fromDb(TransactionTemplate t) {
  final splitsData = jsonDecode(t.splitTemplates) as List;  // ❌ 未验证类型
  final splits = splitsData
      .map((s) => SplitTemplateData.fromJson(s as Map<String, dynamic>))
```

**影响分析**:
- 数据库JSON被篡改或损坏时抛异常
- 模板页面无法打开
- 应用可能崩溃

**修复方案**:
```dart
factory TemplateModel.fromDb(TransactionTemplate t) {
  try {
    final splitsData = jsonDecode(t.splitTemplates);
    if (splitsData is! List) {
      throw FormatException('Invalid template data: expected List');
    }
    final splits = splitsData
        .map((s) {
          if (s is! Map<String, dynamic>) {
            throw FormatException('Invalid split data');
          }
          return SplitTemplateData.fromJson(s);
        })
        .toList();
    return TemplateModel(...);
  } catch (e) {
    // ✅ 返回空模板或记录错误
    logger.error('Failed to parse template ${t.id}: $e');
    rethrow;
  }
}
```

**验证方法**: 注入损坏数据测试恢复能力

---

### 5. 🔴 递归树构建无深度限制 - 栈溢出崩溃
**严重程度**: Critical  
**问题位置**: `apps/mobile/lib/features/accounts/data/account_provider.dart:110-133`

**问题描述**:
```dart
AccountTreeNode _buildTreeNode(
  Account account, 
  List<Account> allAccounts,
  Map<String, double> balances,
) {
  final children = allAccounts
      .where((a) => a.parentId == account.id && !a.isHidden)
      .toList();
  
  final childNodes = children
      .map((child) => _buildTreeNode(child, allAccounts, balances))  // ❌ 无限递归风险
      .toList();
```

**影响分析**:
- 数据库出现循环引用（虽有检查但可能不完善）
- 递归深度过大导致栈溢出
- 应用崩溃

**修复方案**:
```dart
AccountTreeNode _buildTreeNode(
  Account account, 
  List<Account> allAccounts,
  Map<String, double> balances,
  Set<String> visited,  // ✅ 添加访问记录
  int depth,            // ✅ 添加深度限制
) {
  // ✅ 检查循环引用
  if (visited.contains(account.id)) {
    logger.warning('Circular reference detected: ${account.id}');
    return AccountTreeNode(..., children: []);
  }
  
  // ✅ 检查深度
  if (depth > 50) {
    logger.warning('Account hierarchy too deep: ${account.id}');
    return AccountTreeNode(..., children: []);
  }
  
  final newVisited = {...visited, account.id};
  final childNodes = children
      .map((child) => _buildTreeNode(child, allAccounts, balances, newVisited, depth + 1))
      .toList();
  
  return AccountTreeNode(..., children: childNodes);
}
```

**验证方法**: 创建深度账户层级测试，注入循环引用

---

### 6. 🔴 Background isolate数据库访问错误
**严重程度**: Critical  
**问题位置**: `apps/mobile/lib/features/recurring/data/background_recurring_processor.dart:203-213`

**问题描述**:
```dart
Future<LocalFinanceDatabase> _openDatabase() async {
  final executor = driftDatabase(
    name: 'finance',
    native: DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,  // ❌ 异步函数
    ),
  );
  
  return LocalFinanceDatabase.forTesting(executor);  // ❌ 使用测试构造函数
}
```

**影响分析**:
- `getApplicationSupportDirectory` 是异步函数但被当作同步值传递
- 使用 `forTesting` 绕过了加密设置
- 后台任务无法正常访问数据库

**修复方案**:
```dart
Future<LocalFinanceDatabase> _openDatabase() async {
  final dbDir = await getApplicationSupportDirectory();  // ✅ await异步调用
  final executor = driftDatabase(
    name: 'finance',
    native: DriftNativeOptions(
      databaseDirectory: dbDir.path,
    ),
  );
  
  // ✅ 使用正确的加密数据库构造
  final key = await _getDatabaseKey();
  return LocalFinanceDatabase(executor, key);
}
```

**验证方法**: 验证后台任务能否正常读写数据库

---

### 7. 🔴 导出CSV无数据量限制 - 内存溢出
**严重程度**: Critical  
**问题位置**: `apps/mobile/lib/features/export/data/export_service.dart:99-176`

**问题描述**:
```dart
// 构建所有行到内存
final rows = <List<String>>[];
for (final (transaction, splits) in transactionsWithSplits) {
  for (final split in splits) {
    rows.add([...]);  // ❌ 全部加载到内存
  }
}
final csvString = const ListToCsvConverter().convert(rows);  // ❌ 大文件OOM
```

**影响分析**:
- 导出数万条交易内存溢出
- 应用崩溃
- 大数据量用户无法导出

**修复方案**:
```dart
Future<void> exportTransactionsToCsv(...) async {
  final file = await _getOutputFile('transactions.csv');
  final sink = file.openWrite();  // ✅ 流式写入
  
  try {
    // ✅ 写入CSV头
    sink.writeln('date,description,amount,...');
    
    // ✅ 分页读取并流式写入
    const pageSize = 1000;
    var offset = 0;
    while (true) {
      final transactions = await _db.transactionsDao
          .getTransactionsPaginated(offset, pageSize);
      
      if (transactions.isEmpty) break;
      
      for (final txn in transactions) {
        sink.writeln('${txn.date},${txn.description},${txn.amount},...');
      }
      
      offset += pageSize;
    }
  } finally {
    await sink.close();
  }
}
```

**验证方法**: 导出10万+条交易测试性能

---

### 8. 🔴 货币转换精度丢失 - 报表数据不准确
**严重程度**: Critical  
**问题位置**: `apps/mobile/lib/features/reports/data/balance_history_provider.dart:266-271`

**问题描述**:
```dart
double convertedBalance = balance;
if (account.commodityId != targetCurrency) {
  convertedBalance = await currencyService.convertOrDefault(
    balance,
    account.commodityId,
    targetCurrency,
  );  // ❌ 使用double可能丢失精度
}
```

**影响分析**:
- 金融计算使用浮点数会积累误差
- 报表数据不准确
- 财务对账困难

**修复方案**:
```dart
// 方案1: 使用Decimal包
import 'package:decimal/decimal.dart';

Decimal convertedBalance = Decimal.fromDouble(balance);
if (account.commodityId != targetCurrency) {
  final rate = await currencyService.getExchangeRate(
    account.commodityId,
    targetCurrency,
  );
  convertedBalance = (convertedBalance * Decimal.fromDouble(rate))
      .round(scale: 2);  // ✅ 精确计算
}

// 方案2: 使用整数分币运算
int convertedBalanceNum = balanceNum;  // 单位: 分
if (account.commodityId != targetCurrency) {
  final rateNum = await currencyService.getExchangeRateNum(
    account.commodityId,
    targetCurrency,
  );  // 汇率也用整数表示，放大10000倍
  convertedBalanceNum = (balanceNum * rateNum) ~/ 10000;
}
```

**验证方法**: 对比浮点数和精确计算的结果差异

---

### 9. 🔴 HTTP请求无超时设置 - 网络挂起
**严重程度**: Critical  
**问题位置**: `apps/mobile/lib/features/sync/data/auth_provider_impl.dart:86-93`

**问题描述**:
```dart
final response = await _httpClient.post(
  Uri.parse('$serverUrl/api/auth/login'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({...}),
);  // ❌ 无超时设置
```

**影响分析**:
- 网络慢时永久挂起
- 用户等待无响应
- 应用假死

**修复方案**:
```dart
final response = await _httpClient.post(
  Uri.parse('$serverUrl/api/auth/login'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({...}),
).timeout(
  const Duration(seconds: 30),  // ✅ 30秒超时
  onTimeout: () {
    throw TimeoutException('Login request timeout');
  },
);
```

**验证方法**: 模拟慢网络测试超时处理

---

### 10. 🔴 认证Token存储安全性验证
**严重程度**: Critical  
**问题位置**: `apps/mobile/lib/features/sync/data/auth_provider_impl.dart:276-286`

**问题描述**:
```dart
Future<void> _saveCredentials({...}) async {
  await _storage.write(key: _keyUserId, value: userId);
  await _storage.write(key: _keyToken, value: token);  // ❌ 需要确认平台安全性
  await _storage.write(key: _keyRefreshToken, value: refreshToken);
```

**影响分析**:
- FlutterSecureStorage在不同平台实现不同
- 某些平台可能不够安全
- Token泄露风险

**修复方案**:
```dart
Future<void> _saveCredentials({...}) async {
  // ✅ 验证平台安全性
  if (Platform.isAndroid) {
    final isSecure = await _storage.isProtectedByBiometrics();
    if (!isSecure) {
      // ✅ 添加额外加密层
      final encryptedToken = await _encryptToken(token);
      await _storage.write(key: _keyToken, value: encryptedToken);
    }
  } else if (Platform.isIOS) {
    // ✅ iOS Keychain默认安全
    await _storage.write(key: _keyToken, value: token);
  } else if (kIsWeb) {
    // ⚠️ Web平台需要额外保护
    final encryptedToken = await _encryptToken(token);
    await _storage.write(key: _keyToken, value: encryptedToken);
  }
}

Future<String> _encryptToken(String token) async {
  final key = await _getOrCreateEncryptionKey();
  final encrypted = await _encryptionService.encrypt(token, key);
  return encrypted;
}
```

**验证方法**: 审查各平台FlutterSecureStorage实现文档

---

## 🔶 P1 - 两周内修复 (10个)

### 11. 🟡 空值处理缺失 - 编辑凭证崩溃
**严重程度**: High  
**问题位置**: `apps/mobile/lib/features/journal/providers/journal_entry_provider.dart:239-250`

**问题描述**:
```dart
void updateLineAccount(String lineId, Account account) {
  final newLines = state.lines.map((l) {
    if (l.id == lineId) {
      return l.copyWith(
        accountId: account.id,
        accountName: account.name,
        accountType: account.accountType.code,  // ❌ accountType可能为null
      );
    }
```

**修复方案**:
```dart
accountType: account.accountType?.code ?? AccountType.ASSET.code,  // ✅ 空值处理
```

---

### 12. 🟡 ID生成使用时间戳可能冲突
**严重程度**: High  
**问题位置**: `apps/mobile/lib/features/recurring/data/recurring_provider.dart:78`

**修复方案**:
```dart
final id = const Uuid().v4();  // ✅ 使用UUID
```

---

### 13. 🟡 分页加载无去重机制 - 列表重复
**严重程度**: High  
**问题位置**: `apps/mobile/lib/features/transactions/data/transaction_provider.dart:709-714`

**修复方案**:
```dart
state = state.copyWith(
  items: [...state.items, ...newItems]
      .fold<Map<String, Transaction>>({}, (map, item) {
        map[item.id] = item;  // ✅ 使用Map去重
        return map;
      }).values.toList(),
);
```

---

### 14. 🟡 标签批量操作无事务 - 数据不一致
**严重程度**: High  
**问题位置**: `apps/mobile/lib/features/tags/presentation/widgets/bulk_tag_operation_dialog.dart:186-195`

**修复方案**:
```dart
await _db.transaction(() async {
  for (final tagId in tagIds) {
    await _db.tagsDao.addTagToTransaction(transactionId, tagId);
  }
});  // ✅ 包裹在事务中
```

---

### 15. 🟡 导入文件编码未处理 - 导入崩溃
**严重程度**: High  
**问题位置**: `apps/mobile/lib/features/settings/data/backup_provider.dart:128`

**修复方案**:
```dart
try {
  final bytes = await file.readAsBytes();
  final content = utf8.decode(bytes, allowMalformed: true);  // ✅ 允许错误字符
  final data = jsonDecode(content) as Map<String, dynamic>;
} catch (e) {
  // ✅ 尝试其他编码
  final content = await file.readAsString(encoding: latin1);
  final data = jsonDecode(content) as Map<String, dynamic>;
}
```

---

### 16. 🟡 分页加载错误恢复机制缺失
**严重程度**: High  
**问题位置**: `apps/mobile/lib/features/transactions/data/transaction_provider.dart:681-738`

**修复方案**:
```dart
// ✅ 添加错误状态和重试UI
if (state.hasError) {
  return Center(
    child: Column(
      children: [
        Text('加载失败: ${state.error}'),
        ElevatedButton(
          onPressed: () => ref.read(paginatedTransactionsProvider.notifier).retry(),
          child: Text('重试'),
        ),
      ],
    ),
  );
}
```

---

### 17. 🟡 预算计算未处理categoryId为null的情况
**严重程度**: High  
**问题位置**: `packages/database/lib/src/daos/budgets_dao.dart:69-85`

**修复方案**:
```dart
Future<int> calculateSpentAmountNum({
  required String? categoryId,
  ...
}) async {
  if (categoryId == null) {
    logger.warning('categoryId is null, calculating total expenses');  // ✅ 记录日志
    // ... 总体预算计算
  } else {
    // ... 分类预算计算
  }
}
```

---

### 18. 🟡 AI建议无防抖取消机制
**严重程度**: High  
**问题位置**: `apps/mobile/lib/features/transactions/presentation/widgets/add_transaction_dialog.dart:78-102`

**修复方案**:
```dart
CancelableOperation<String>? _aiRequest;

void _onDescriptionChanged() {
  _debounceTimer?.cancel();
  _aiRequest?.cancel();  // ✅ 取消之前的AI请求
  
  _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
    _aiRequest = CancelableOperation.fromFuture(
      _getAiSuggestion(description),
      onCancel: () => print('AI request cancelled'),
    );
    final suggestion = await _aiRequest?.value;
    // ... 使用建议
  });
}
```

---

### 19. 🟡 删除分类无级联处理
**严重程度**: High  
**问题位置**: `apps/mobile/lib/features/categories/data/category_provider.dart:90-98`

**修复方案**:
```dart
Future<void> deleteCategory(String id) async {
  final transactions = await _db.transactionsDao.getByCategory(id);
  if (transactions.isNotEmpty) {
    // ✅ 选项1: 阻止删除并提示
    throw StateError('Cannot delete: ${transactions.length} transactions use this category');
    
    // ✅ 选项2: 迁移到默认分类
    await _db.transaction(() async {
      await _db.transactionsDao.updateCategory(id, defaultCategoryId);
      await _db.categoriesDao.delete(id);
    });
  }
}
```

---

### 20. 🟡 搜索功能潜在SQL注入
**严重程度**: High  
**问题位置**: `apps/mobile/lib/features/import/providers/import_providers.dart:608-610`

**修复方案**:
```dart
// ✅ 使用参数化查询
if (query.searchText != null && query.searchText!.isNotEmpty) {
  final escapedSearch = query.searchText!.replaceAll('%', '\\%').replaceAll('_', '\\_');
  q = q..where((t) => t.description.like('%$escapedSearch%'));
}
```

---

## 🔸 P2 - 一个月内修复 (10个)

### 21. 🟢 错误状态仅返回空列表 - 用户困惑
**严重程度**: Medium  
**问题位置**: `apps/mobile/lib/features/accounts/data/account_provider.dart:19-24, 38-40`

**修复方案**:
```dart
return accounts.when(
  data: (list) => list.where((a) => a.accountType == type).toList(),
  loading: () => [],
  error: (error, stack) {
    logger.error('Failed to load accounts', error, stack);
    ref.read(errorNotifierProvider).showError('加载账户失败');
    return [];  // ✅ 显示错误但返回空列表
  },
);
```

---

### 22. 🟢 预算进度百分比可超过100%未处理
**严重程度**: Medium  
**问题位置**: `packages/database/lib/src/daos/budgets_dao.dart:148-165`

**修复方案**:
```dart
Future<double> getProgress({...}) async {
  final spent = spentNum / 100.0;
  final progress = spent / budgetAmount;
  
  // ✅ UI层决定显示方式，DAO返回原始值
  return progress;  // 可能>1，UI显示为超支状态
}
```

---

### 23. 🟢 余额历史计算性能问题
**严重程度**: Medium  
**问题位置**: `apps/mobile/lib/features/reports/data/balance_history_provider.dart:95-115`

**修复方案**:
```dart
// ✅ 一次性计算所有周期的余额
final allTransactions = await _db.transactionsDao.getAllTransactionsOrdered();
final balancesByDate = <DateTime, Map<String, double>>{};
var runningBalance = <String, double>{};

for (final txn in allTransactions) {
  final date = DateTime.fromMillisecondsSinceEpoch(txn.postDate);
  // 累积计算余额
  runningBalance[txn.accountId] = (runningBalance[txn.accountId] ?? 0) + txn.amount;
  balancesByDate[date] = Map.from(runningBalance);
}
```

---

### 24. 🟢 缺少并发控制 - 快速点击创建重复交易
**严重程度**: Medium  
**问题位置**: `apps/mobile/lib/features/transactions/data/transaction_provider.dart:306-373`

**修复方案**:
```dart
bool _isCreating = false;  // ✅ 添加状态锁

Future<String?> createTransaction({...}) async {
  if (_isCreating) {
    return null;  // ✅ 防止重复创建
  }
  
  _isCreating = true;
  try {
    // ... 创建逻辑
  } finally {
    _isCreating = false;
  }
}
```

---

### 25. 🟢 缓存失效不完整
**严重程度**: Medium  
**问题位置**: `apps/mobile/lib/features/transactions/data/transaction_provider.dart:302-304`

**修复方案**:
```dart
void _invalidateRelatedCaches() {
  _ref.read(cacheInvalidationNotifierProvider.notifier).onTransactionChanged();
  _ref.read(budgetsProvider.notifier).invalidate();  // ✅ 失效预算缓存
  _ref.read(accountsProvider.notifier).invalidate(); // ✅ 失效账户余额缓存
  _ref.read(reportsProvider.notifier).invalidate();   // ✅ 失效报表缓存
}
```

---

### 26. 🟢 投资收益计算使用简化算法
**严重程度**: Medium  
**问题位置**: `apps/mobile/lib/features/investments/data/investment_provider.dart:144`

**修复方案**:
```dart
// ✅ 实现FIFO成本计算
Future<double> calculateRealizedGainsFifo(String accountId) async {
  final holdings = <String, Queue<(int, double)>>{};  // (quantity, cost)
  
  final transactions = await _db.investmentTransactionsDao.getByAccount(accountId);
  
  double realizedGains = 0;
  
  for (final txn in transactions) {
    if (txn.type == TransactionType.BUY) {
      holdings.putIfAbsent(txn.securitySymbol, () => Queue());
      holdings[txn.securitySymbol]!.add((txn.quantity, txn.price));
    } else if (txn.type == TransactionType.SELL) {
      var remaining = txn.quantity;
      while (remaining > 0 && holdings[txn.securitySymbol]!.isNotEmpty) {
        final lot = holdings[txn.securitySymbol]!.removeFirst();
        final soldFromLot = min(remaining, lot.$1);
        realizedGains += soldFromLot * (txn.price - lot.$2);
        remaining -= soldFromLot;
        
        if (lot.$1 > soldFromLot) {
          holdings[txn.securitySymbol]!.addFirst((lot.$1 - soldFromLot, lot.$2));
        }
      }
    }
  }
  
  return realizedGains;
}
```

---

### 27. 🟢 模板JSON解析无版本兼容
**严重程度**: Medium  
**问题位置**: `apps/mobile/lib/features/templates/data/template_provider.dart:34-41`

**修复方案**:
```dart
factory SplitTemplateData.fromJson(Map<String, dynamic> json) {
  return SplitTemplateData(
    accountId: json['accountId'] as String? ?? '',  // ✅ 默认值
    categoryId: json['categoryId'] as String?,
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,  // ✅ 空值处理
    memo: json['memo'] as String?,
    version: json['version'] as int? ?? 1,  // ✅ 版本字段
  );
}
```

---

### 28. 🟢 缺少输入验证 - 数据损坏崩溃
**严重程度**: Medium  
**问题位置**: `apps/mobile/lib/features/transactions/presentation/widgets/add_transaction_dialog.dart:130-151`

**修复方案**:
```dart
final amount = split.valueDenom != 0  // ✅ 检查除零
    ? split.valueNum.abs() / split.valueDenom
    : 0.0;
```

---

### 29. 🟢 缺少撤销功能 - 误操作无法恢复
**严重程度**: Medium  
**问题位置**: 删除操作多处

**修复方案**:
```dart
// ✅ 实现软删除+撤销
Future<void> deleteTransaction(String id) async {
  await _db.transactionsDao.softDelete(id);  // 标记为deleted
  ref.read(undoStackProvider.notifier).push(
    UndoAction(
      type: UndoActionType.delete,
      data: await _db.transactionsDao.getById(id),
      execute: () => _db.transactionsDao.restore(id),
    ),
  );
}

// ✅ 提供撤销Snackbar
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('已删除交易'),
    action: SnackBarAction(
      label: '撤销',
      onPressed: () => ref.read(undoStackProvider.notifier).undo(),
    ),
  ),
);
```

---

### 30. 🟢 缺少空状态引导 - 新用户困惑
**严重程度**: Medium  
**问题位置**: `apps/mobile/lib/features/transactions/presentation/pages/transactions_page.dart:238-265`

**修复方案**:
```dart
Widget _buildEmptyState(BuildContext context) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text('还没有交易记录'),
        SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _showAddTransactionDialog(context),
          icon: Icon(Icons.add),
          label: Text('添加第一笔交易'),  // ✅ 引导操作
        ),
        SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _showImportDialog(context),
          icon: Icon(Icons.upload_file),
          label: Text('或导入账单'),  // ✅ 提供导入选项
        ),
      ],
    ),
  );
}
```

---

## 📊 优先级分布

| 优先级 | 数量 | 时间框架 | 关键特征 |
|--------|------|----------|----------|
| 🔥 P0 | 10个 | 本周内 | 可能导致崩溃、数据丢失、安全漏洞 |
| 🔶 P1 | 10个 | 两周内 | 严重影响用户体验、数据一致性 |
| 🔸 P2 | 10个 | 一个月内 | 影响体验、性能、可维护性 |

---

## 🎯 修复策略建议

### 分阶段修复

#### Week 1: P0 Critical Fixes
- **Day 1-2**: #1, #2, #3 (数据库相关)
- **Day 3-4**: #4, #5, #6 (崩溃风险)
- **Day 5**: #7, #8 (性能与精度)
- **Day 6-7**: #9, #10 (安全与网络)

#### Week 2: P1 High Priority
- **Day 1-2**: #11-15 (错误处理)
- **Day 3-4**: #16-20 (数据一致性)

#### Week 3-4: P2 Medium Priority
- **Week 3**: #21-25 (用户体验)
- **Week 4**: #26-30 (功能完善)

### 测试策略

1. **单元测试**: 为每个修复添加测试用例
2. **集成测试**: 验证修复后的端到端流程
3. **压力测试**: 模拟大数据量、并发场景
4. **回归测试**: 确保修复未引入新问题

### 发布计划

- **v0.3.232**: P0修复 (本周五)
- **v0.3.233**: P1修复 (下周五)
- **v0.3.234**: P2修复 (两周后周五)

---

## 📝 后续改进建议

完成Top 30后，建议继续处理：

1. **Performance Optimization**: 性能监控和优化
2. **Accessibility**: 辅助功能支持
3. **Internationalization**: 完善多语言支持
4. **Documentation**: API文档和用户手册
5. **Testing Coverage**: 提升测试覆盖率到80%+

---

**最后更新**: 2026-06-08  
**下次评审**: 完成P0修复后进行进度review
