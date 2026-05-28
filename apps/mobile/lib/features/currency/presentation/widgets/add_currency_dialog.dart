import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance_app/features/currency/data/currency_provider.dart';

/// Dialog for adding a new currency
class AddCurrencyDialog extends ConsumerStatefulWidget {
  const AddCurrencyDialog({super.key});

  @override
  ConsumerState<AddCurrencyDialog> createState() => _AddCurrencyDialogState();
}

class _AddCurrencyDialogState extends ConsumerState<AddCurrencyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _fullNameController = TextEditingController();
  int _fraction = 100;

  // Common currency presets
  static const _currencyPresets = [
    ('USD', 'US Dollar', '美元'),
    ('EUR', 'Euro', '欧元'),
    ('GBP', 'British Pound', '英镑'),
    ('JPY', 'Japanese Yen', '日元'),
    ('KRW', 'Korean Won', '韩元'),
    ('HKD', 'Hong Kong Dollar', '港币'),
    ('SGD', 'Singapore Dollar', '新加坡元'),
    ('AUD', 'Australian Dollar', '澳元'),
    ('CAD', 'Canadian Dollar', '加元'),
    ('CHF', 'Swiss Franc', '瑞士法郎'),
    ('THB', 'Thai Baht', '泰铢'),
    ('MYR', 'Malaysian Ringgit', '马来西亚林吉特'),
  ];

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Currency'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Quick presets
            Text(
              'Quick Add',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _currencyPresets.map((preset) {
                return ActionChip(
                  label: Text(preset.$1),
                  onPressed: () {
                    _idController.text = preset.$1;
                    _nameController.text = preset.$1;
                    _fullNameController.text = preset.$3;
                    if (preset.$1 == 'JPY' || preset.$1 == 'KRW') {
                      _fraction = 1;
                    } else {
                      _fraction = 100;
                    }
                    setState(() {});
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Manual entry
            Text(
              'Or Enter Manually',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'Currency Code',
                hintText: 'e.g., USD',
                border: OutlineInputBorder(),
                helperText: 'ISO 4217 format (3 uppercase letters)',
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a currency code';
                }
                if (value.length != 3) {
                  return 'Currency code must be exactly 3 letters';
                }
                if (!RegExp(r'^[A-Z]{3}$').hasMatch(value)) {
                  return 'Currency code must be 3 uppercase letters (A-Z)';
                }
                return null;
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Symbol/Short Name',
                hintText: 'e.g., \$',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a symbol or short name';
                }
                return null;
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name (Chinese)',
                hintText: 'e.g., 美元',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),

            // Fraction (decimal places)
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'Decimal Places',
                border: OutlineInputBorder(),
              ),
              value: _fraction,
              items: const [
                DropdownMenuItem(value: 1, child: Text('0 (e.g., JPY, KRW)')),
                DropdownMenuItem(value: 10, child: Text('1 decimal')),
                DropdownMenuItem(value: 100, child: Text('2 decimals (standard)')),
                DropdownMenuItem(value: 1000, child: Text('3 decimals')),
              ],
              onChanged: (value) {
                setState(() {
                  _fraction = value ?? 100;
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
          child: const Text('Add'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    ref.read(commodityNotifierProvider.notifier).addCurrency(
      id: _idController.text.toUpperCase(),
      mnemonic: _nameController.text,
      fullName: _fullNameController.text,
      fraction: _fraction,
    );
    Navigator.pop(context);
  }
}