import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:finance_app/features/currency/data/currency_provider.dart';

/// Dialog for adding a new exchange rate
class AddExchangeRateDialog extends ConsumerStatefulWidget {
  const AddExchangeRateDialog({super.key});

  @override
  ConsumerState<AddExchangeRateDialog> createState() => _AddExchangeRateDialogState();
}

class _AddExchangeRateDialogState extends ConsumerState<AddExchangeRateDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _fromCurrency;
  String? _toCurrency;
  final _rateController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _source = 'manual';

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencies = ref.watch(currenciesProvider);

    return AlertDialog(
      title: const Text('Add Exchange Rate'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // From currency
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'From Currency',
                border: OutlineInputBorder(),
              ),
              value: _fromCurrency,
              items: currencies.map((c) {
                return DropdownMenuItem(
                  value: c.id,
                  child: Text('${c.mnemonic} - ${c.fullName ?? c.id}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _fromCurrency = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // To currency
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'To Currency',
                border: OutlineInputBorder(),
              ),
              value: _toCurrency,
              items: currencies.map((c) {
                return DropdownMenuItem(
                  value: c.id,
                  child: Text('${c.mnemonic} - ${c.fullName ?? c.id}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _toCurrency = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Rate
            TextFormField(
              controller: _rateController,
              decoration: const InputDecoration(
                labelText: 'Exchange Rate',
                hintText: 'e.g., 7.25',
                border: OutlineInputBorder(),
                helperText: 'Must be a positive number',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an exchange rate';
                }
                final rate = double.tryParse(value);
                if (rate == null) {
                  return 'Please enter a valid number';
                }
                if (rate <= 0) {
                  return 'Exchange rate must be positive';
                }
                return null;
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 16),

            // Date picker
            ListTile(
              title: const Text('Rate Date'),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Source
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Source',
                border: OutlineInputBorder(),
              ),
              value: _source,
              items: const [
                DropdownMenuItem(value: 'manual', child: Text('Manual Entry')),
                DropdownMenuItem(value: 'bank', child: Text('Bank Rate')),
                DropdownMenuItem(value: 'market', child: Text('Market Rate')),
                DropdownMenuItem(value: 'api', child: Text('API Import')),
              ],
              onChanged: (value) {
                setState(() {
                  _source = value ?? 'manual';
                });
              },
            ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_fromCurrency == null || _toCurrency == null || _fromCurrency == _toCurrency) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select different currencies')),
      );
      return;
    }
    final rate = double.tryParse(_rateController.text);
    if (rate == null || rate <= 0) {
      return; // Should not happen due to validation
    }
    ref.read(exchangeRateNotifierProvider.notifier).addRate(
      fromCurrency: _fromCurrency!,
      toCurrency: _toCurrency!,
      rate: rate,
      date: _selectedDate,
      source: _source,
    );
    Navigator.pop(context);
  }
}