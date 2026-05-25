import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/currency/data/currency_provider.dart';
import 'package:finance_app/features/currency/presentation/widgets/add_exchange_rate_dialog.dart';
import 'package:finance_app/features/currency/presentation/widgets/add_currency_dialog.dart';

/// Currency settings page - comprehensive multi-currency management
/// Features:
/// - Default currency selection
/// - Currency list with rates
/// - Exchange rate management
/// - Currency conversion preview
class CurrencySettingsPage extends ConsumerStatefulWidget {
  const CurrencySettingsPage({super.key});

  @override
  ConsumerState<CurrencySettingsPage> createState() => _CurrencySettingsPageState();
}

class _CurrencySettingsPageState extends ConsumerState<CurrencySettingsPage> {
  String _defaultCurrency = 'CNY';
  final _convertAmountController = TextEditingController(text: '100');
  String _convertFromCurrency = 'USD';
  String _convertToCurrency = 'CNY';

  @override
  void initState() {
    super.initState();
    _loadDefaultCurrency();
  }

  void _loadDefaultCurrency() {
    // In a real app, this would be loaded from SharedPreferences
    // For now, default to CNY
    _defaultCurrency = 'CNY';
  }

  @override
  void dispose() {
    _convertAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currenciesAsync = ref.watch(currenciesProvider);
    final ratesAsync = ref.watch(exchangeRatesProvider);
    final currenciesWithRatesAsync = ref.watch(currenciesWithRatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('货币设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '添加货币',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const AddCurrencyDialog(),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Default Currency Section
          _buildDefaultCurrencySection(currenciesAsync),
          const SizedBox(height: 24),

          // Currency List with Rates
          _buildCurrencyListSection(currenciesWithRatesAsync),
          const SizedBox(height: 24),

          // Exchange Rates Management
          _buildExchangeRatesSection(ratesAsync, currenciesAsync),
          const SizedBox(height: 24),

          // Currency Converter
          _buildCurrencyConverterSection(currenciesAsync),
          const SizedBox(height: 24),

          // Account Currency Assignment Info
          _buildAccountCurrencyInfo(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const AddExchangeRateDialog(),
          );
        },
        child: const Icon(Icons.add),
        tooltip: '添加汇率',
      ),
    );
  }

  /// Default currency selection section
  Widget _buildDefaultCurrencySection(List<Commodity> currencies) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '默认货币',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '所有报表和汇总将以此货币显示',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '默认货币',
                border: OutlineInputBorder(),
              ),
              value: _defaultCurrency,
              items: currencies.map((c) {
                return DropdownMenuItem(
                  value: c.id,
                  child: Row(
                    children: [
                      if (c.id == _defaultCurrency)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.star,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      Text('${c.mnemonic} - ${c.fullName ?? c.id}'),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _defaultCurrency = value;
                  });
                  // In a real app, save to SharedPreferences
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('默认货币已更改为 $value'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Currency list with their exchange rates
  Widget _buildCurrencyListSection(AsyncValue<List<CurrencyWithRate>> currenciesWithRates) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.currency_exchange,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '货币列表',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                Text(
                  '基准: $_defaultCurrency',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            currenciesWithRates.when(
              data: (currencies) {
                if (currencies.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('暂无配置的货币'),
                  );
                }
                return Column(
                  children: currencies.map((cwr) {
                    return _buildCurrencyRateTile(cwr);
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, st) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('加载失败: $e'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyRateTile(CurrencyWithRate cwr) {
    final isDefault = cwr.currency.id == _defaultCurrency;
    final hasRate = cwr.rateToBase != null;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isDefault
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        child: Text(
          cwr.currency.mnemonic,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isDefault ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
      title: Text(
        '${cwr.currency.fullName ?? cwr.currency.id}${isDefault ? ' (默认)' : ''}',
      ),
      subtitle: hasRate
          ? Text(
              '汇率: ${cwr.rateToBase!.toStringAsFixed(4)} • ${cwr.rateDate != null ? _formatDate(cwr.rateDate!.millisecondsSinceEpoch) : '未知'}',
            )
          : const Text(
              '未设置汇率',
              style: TextStyle(color: Colors.orange),
            ),
      trailing: hasRate
          ? Text(
              cwr.rateSource ?? 'manual',
              style: Theme.of(context).textTheme.bodySmall,
            )
          : TextButton(
              onPressed: () {
                _showQuickAddRateDialog(cwr.currency.id, _defaultCurrency);
              },
              child: const Text('添加汇率'),
            ),
    );
  }

  /// Exchange rates management section
  Widget _buildExchangeRatesSection(
    AsyncValue<List<ExchangeRate>> ratesAsync,
    List<Commodity> currencies,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '汇率管理',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '手动输入或更新汇率',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ratesAsync.when(
              data: (rates) {
                if (rates.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.currency_exchange, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('暂无汇率数据'),
                          SizedBox(height: 4),
                          Text(
                            '点击右下角 + 添加汇率',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Group rates by currency pair
                final groupedRates = <String, List<ExchangeRate>>{};
                for (final rate in rates) {
                  final key = '${rate.fromCurrency}_${rate.toCurrency}';
                  groupedRates.putIfAbsent(key, () => []).add(rate);
                }

                return Column(
                  children: groupedRates.entries.map((entry) {
                    final pairRates = entry.value;
                    final latestRate = pairRates.first;

                    return ExpansionTile(
                      leading: CircleAvatar(
                        child: Text(
                          '${latestRate.fromCurrency}/${latestRate.toCurrency}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      title: Text(
                        '${latestRate.fromCurrency} → ${latestRate.toCurrency}',
                      ),
                      subtitle: Text(
                        '当前汇率: ${latestRate.rate.toStringAsFixed(4)}',
                      ),
                      children: pairRates.map((rate) {
                        return ListTile(
                          title: Text('汇率: ${rate.rate.toStringAsFixed(4)}'),
                          subtitle: Text(
                            '${_formatDate(rate.date)} • 来源: ${rate.source}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () {
                                  _showEditRateDialog(rate);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                color: Colors.red,
                                onPressed: () {
                                  _confirmDeleteRate(rate);
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, st) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('加载失败: $e'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Currency converter section
  Widget _buildCurrencyConverterSection(List<Commodity> currencies) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                Icon(
                  Icons.calculate,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '货币转换',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Amount input
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _convertAmountController,
                    decoration: const InputDecoration(
                      labelText: '金额',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                // From currency
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: '从',
                      border: OutlineInputBorder(),
                    ),
                    value: _convertFromCurrency,
                    items: currencies.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(c.mnemonic),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _convertFromCurrency = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Swap button
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: () {
                    setState(() {
                      final temp = _convertFromCurrency;
                      _convertFromCurrency = _convertToCurrency;
                      _convertToCurrency = temp;
                    });
                  },
                ),
                const SizedBox(width: 8),
                // To currency
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: '到',
                      border: OutlineInputBorder(),
                    ),
                    value: _convertToCurrency,
                    items: currencies.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(c.mnemonic),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _convertToCurrency = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Conversion result
            _buildConversionResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildConversionResult() {
    final amount = double.tryParse(_convertAmountController.text);
    if (amount == null) {
      return const Text('请输入有效金额');
    }

    final converter = ref.watch(currencyConverterProvider);
    final resultAsync = ref.watch(
      currencyConversionProvider(
        (amount, _convertFromCurrency, _convertToCurrency),
      ),
    );

    return resultAsync.when(
      data: (result) {
        if (result == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '无法转换: 缺少 $_convertFromCurrency → $_convertToCurrency 的汇率',
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_formatAmount(amount)} $_convertFromCurrency',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward),
              const SizedBox(width: 8),
              Text(
                '${_formatAmount(result)} $_convertToCurrency',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Text('转换失败: $e'),
    );
  }

  /// Account currency assignment info
  Widget _buildAccountCurrencyInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '账户货币设置',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '每个账户可以设置独立的货币。在账户详情页面中可以更改账户货币。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('管理账户'),
              onPressed: () {
                context.push('/accounts');
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,##0.00').format(amount);
  }

  void _showQuickAddRateDialog(String fromCurrency, String toCurrency) {
    final rateController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('添加汇率: $fromCurrency → $toCurrency'),
        content: TextField(
          controller: rateController,
          decoration: const InputDecoration(
            labelText: '汇率',
            hintText: '例如: 7.25',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final rate = double.tryParse(rateController.text);
              if (rate != null && rate > 0) {
                ref.read(exchangeRateNotifierProvider.notifier).addRate(
                  fromCurrency: fromCurrency,
                  toCurrency: toCurrency,
                  rate: rate,
                  date: DateTime.now(),
                  source: 'manual',
                );
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showEditRateDialog(ExchangeRate rate) {
    final controller = TextEditingController(text: rate.rate.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑汇率'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '汇率',
            hintText: '输入新汇率',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final newRate = double.tryParse(controller.text);
              if (newRate != null && newRate > 0) {
                ref.read(exchangeRateNotifierProvider.notifier).updateRate(rate.id, newRate);
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRate(ExchangeRate rate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除汇率'),
        content: Text(
          '确定删除汇率 ${rate.fromCurrency} → ${rate.toCurrency} (${rate.rate})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(exchangeRateNotifierProvider.notifier).deleteRate(rate.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// Provider for currency conversion result
final currencyConversionProvider = FutureProvider.family<double?, (double, String, String)>((ref, params) async {
  final (amount, from, to) = params;
  final converter = ref.watch(currencyConverterProvider);
  return converter.convert(amount, from, to);
});
