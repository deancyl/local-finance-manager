import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:database/database.dart';
import 'package:finance_app/features/currency/data/currency_provider.dart';
import 'package:finance_app/features/currency/presentation/widgets/add_exchange_rate_dialog.dart';
import 'package:finance_app/features/currency/presentation/widgets/add_currency_dialog.dart';

/// Exchange rates management page
class ExchangeRatesPage extends ConsumerWidget {
  const ExchangeRatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratesAsync = ref.watch(exchangeRatesProvider);
    final currenciesAsync = ref.watch(currenciesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exchange Rates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Currency',
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
          // Currency list card
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
                        'Supported Currencies',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Base: CNY',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final currencies = currenciesAsync;
                      if (currencies.isEmpty) {
                        return const Text('No currencies configured');
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: currencies.map((c) {
                          return Chip(
                            label: Text('${c.mnemonic} - ${c.fullName ?? c.id}'),
                            backgroundColor: c.id == 'CNY'
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

          // Exchange rates list
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
                        Text('No exchange rates configured'),
                        SizedBox(height: 8),
                        Text(
                          'Tap + to add your first rate',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Group rates by currency pair
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
                          'Rate: ${latestRate.rate.toStringAsFixed(4)} • ${_formatDate(latestRate.date)}',
                        ),
                        trailing: Text(
                          latestRate.source,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        children: pairRates.map((rate) {
                          return ListTile(
                            title: Text('Rate: ${rate.rate.toStringAsFixed(4)}'),
                            subtitle: Text(
                              '${_formatDate(rate.date)} • Source: ${rate.source}',
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
                    Text('Error loading rates: $e'),
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

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('yyyy-MM-dd').format(date);
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, ExchangeRate rate) {
    final controller = TextEditingController(text: rate.rate.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Exchange Rate'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Rate',
            hintText: 'Enter new rate',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newRate = double.tryParse(controller.text);
              if (newRate != null && newRate > 0) {
                ref.read(exchangeRateNotifierProvider.notifier).updateRate(rate.id, newRate);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ExchangeRate rate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rate'),
        content: Text(
          'Delete rate ${rate.fromCurrency} → ${rate.toCurrency} (${rate.rate})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(exchangeRateNotifierProvider.notifier).deleteRate(rate.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
