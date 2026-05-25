import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/currency/data/currency_provider.dart';
import 'package:finance_app/features/currency/presentation/widgets/add_exchange_rate_dialog.dart';
import 'package:finance_app/features/currency/presentation/widgets/add_currency_dialog.dart';
import 'package:finance_app/features/currency/presentation/pages/rate_history_page.dart';

/// 汇率管理页面
class ExchangeRatesPage extends ConsumerStatefulWidget {
  const ExchangeRatesPage({super.key});

  @override
  ConsumerState<ExchangeRatesPage> createState() => _ExchangeRatesPageState();
}

class _ExchangeRatesPageState extends ConsumerState<ExchangeRatesPage> {
  @override
  void initState() {
    super.initState();
    // 启动自动更新
    Future.microtask(() {
      final settings = ref.read(autoUpdateSettingsProvider);
      if (settings.enabled) {
        ref.read(enhancedExchangeRateNotifierProvider.notifier).startAutoUpdate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ratesAsync = ref.watch(exchangeRatesProvider);
    final currenciesAsync = ref.watch(currenciesProvider);
    final settings = ref.watch(autoUpdateSettingsProvider);
    final needsUpdate = ref.watch(ratesNeedUpdateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('汇率管理'),
        actions: [
          // 自动更新开关
          Switch(
            value: settings.enabled,
            onChanged: (value) {
              ref.read(autoUpdateSettingsProvider.notifier).setEnabled(value);
              if (value) {
                ref.read(enhancedExchangeRateNotifierProvider.notifier).startAutoUpdate();
              } else {
                ref.read(enhancedExchangeRateNotifierProvider.notifier).stopAutoUpdate();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () => _showSettingsDialog(context),
          ),
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
      body: Column(
        children: [
          // 货币列表卡片
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '支持的货币',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Row(
                        children: [
                          Text(
                            '基准: ${settings.baseCurrency}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(width: 8),
                          needsUpdate.when(
                            data: (needs) => needs
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '需更新',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final currencies = currenciesAsync;
                      if (currencies.isEmpty) {
                        return const Text('未配置货币');
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: currencies.map((c) {
                          return Chip(
                            label: Text('${c.mnemonic} - ${c.fullName ?? c.id}'),
                            backgroundColor: c.id == settings.baseCurrency
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 操作按钮行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final alerts = await ref
                            .read(enhancedExchangeRateNotifierProvider.notifier)
                            .fetchAndUpdateRates();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('汇率已更新${alerts.isNotEmpty ? '，有${alerts.length}个显著变动' : ''}'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('更新失败: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('立即更新'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showManualRateDialog(context),
                    icon: const Icon(Icons.edit),
                    label: const Text('手动输入'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 汇率列表
          Expanded(
            child: ratesAsync.when(
              data: (rates) {
                if (rates.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.currency_exchange, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('未配置汇率'),
                        SizedBox(height: 8),
                        Text(
                          '点击 + 添加第一个汇率',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // 按货币对分组
                final groupedRates = <String, List<ExchangeRate>>{};
                for (final rate in rates) {
                  final key = '${rate.fromCurrency}_${rate.toCurrency}';
                  groupedRates.putIfAbsent(key, () => []).add(rate);
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: groupedRates.length,
                  itemBuilder: (context, index) {
                    final entry = groupedRates.entries.elementAt(index);
                    final pairRates = entry.value;
                    final latestRate = pairRates.first;

                    return Card(
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          child: Text(latestRate.fromCurrency),
                        ),
                        title: Text('${latestRate.fromCurrency} → ${latestRate.toCurrency}'),
                        subtitle: Text(
                          '汇率: ${latestRate.rate.toStringAsFixed(4)} • ${_formatDate(latestRate.date)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSourceChip(latestRate.source),
                            IconButton(
                              icon: const Icon(Icons.show_chart, size: 20),
                              tooltip: '查看历史',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RateHistoryPage(
                                      fromCurrency: latestRate.fromCurrency,
                                      toCurrency: latestRate.toCurrency,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        children: pairRates.take(5).map((rate) {
                          return ListTile(
                            title: Text('汇率: ${rate.rate.toStringAsFixed(4)}'),
                            subtitle: Text(
                              '${_formatDate(rate.date)} • 来源: ${_getSourceLabel(rate.source)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () {
                                    _showEditDialog(context, ref, rate);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  color: Colors.red,
                                  onPressed: () {
                                    _confirmDelete(context, ref, rate);
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('加载汇率失败: $e'),
                  ],
                ),
              ),
            ),
          ),
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
      ),
    );
  }

  Widget _buildSourceChip(String source) {
    Color color;
    String label;
    
    switch (source) {
      case 'manual':
        color = Colors.orange;
        label = '手动';
        break;
      case 'open.er-api':
        color = Colors.blue;
        label = 'API';
        break;
      case 'exchangerate-api':
        color = Colors.green;
        label = 'API';
        break;
      default:
        color = Colors.grey;
        label = source;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
  }

  String _getSourceLabel(String source) {
    switch (source) {
      case 'manual':
        return '手动输入';
      case 'open.er-api':
        return 'Open ER API';
      case 'exchangerate-api':
        return 'ExchangeRate API';
      default:
        return source;
    }
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('yyyy-MM-dd').format(date);
  }

  void _showSettingsDialog(BuildContext context) {
    final settings = ref.read(autoUpdateSettingsProvider);
    final intervalController = TextEditingController(
      text: settings.interval.inHours.toString(),
    );
    final thresholdController = TextEditingController(
      text: settings.alertThreshold.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('汇率设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: intervalController,
              decoration: const InputDecoration(
                labelText: '更新间隔（小时）',
                hintText: '输入小时数',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: thresholdController,
              decoration: const InputDecoration(
                labelText: '变动提醒阈值（%）',
                hintText: '输入百分比',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final hours = int.tryParse(intervalController.text) ?? 6;
              final threshold = double.tryParse(thresholdController.text) ?? 5.0;
              
              ref.read(autoUpdateSettingsProvider.notifier).setInterval(
                Duration(hours: hours),
              );
              ref.read(autoUpdateSettingsProvider.notifier).setAlertThreshold(threshold);
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('设置已保存')),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showManualRateDialog(BuildContext context) {
    final fromController = TextEditingController();
    final toController = TextEditingController();
    final rateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('手动输入汇率'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fromController,
              decoration: const InputDecoration(
                labelText: '源货币',
                hintText: '如: USD',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: toController,
              decoration: const InputDecoration(
                labelText: '目标货币',
                hintText: '如: CNY',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: rateController,
              decoration: const InputDecoration(
                labelText: '汇率',
                hintText: '如: 7.2',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final from = fromController.text.toUpperCase();
              final to = toController.text.toUpperCase();
              final rate = double.tryParse(rateController.text);

              if (from.isNotEmpty && to.isNotEmpty && rate != null && rate > 0) {
                await ref
                    .read(enhancedExchangeRateNotifierProvider.notifier)
                    .addManualRate(
                      fromCurrency: from,
                      toCurrency: to,
                      rate: rate,
                    );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('汇率已添加')),
                  );
                }
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, ExchangeRate rate) {
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

  void _confirmDelete(BuildContext context, WidgetRef ref, ExchangeRate rate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除汇率'),
        content: Text(
          '确定删除汇率 ${rate.fromCurrency} → ${rate.toCurrency} (${rate.rate})？',
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
