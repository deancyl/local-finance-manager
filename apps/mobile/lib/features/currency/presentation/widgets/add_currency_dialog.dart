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

            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'Currency Code',
                hintText: 'e.g., USD',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 3,
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Symbol/Short Name',
                hintText: 'e.g., \$',
                border: OutlineInputBorder(),
              ),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSave() ? _save : null,
          child: const Text('Add'),
        ),
      ],
    );
  }

  bool _canSave() {
    return _idController.text.length == 3 &&
        _nameController.text.isNotEmpty;
  }

  void _save() {
    ref.read(commodityNotifierProvider.notifier).addCurrency(
      id: _idController.text.toUpperCase(),
      mnemonic: _nameController.text,
      fullName: _fullNameController.text,
      fraction: _fraction,
    );
    Navigator.pop(context);
  }
}