import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Journal entry editor page for double-entry bookkeeping.
class JournalEntryEditorPage extends ConsumerStatefulWidget {
  final String? entryId;
  
  const JournalEntryEditorPage({
    super.key,
    this.entryId,
  });
  
  @override
  ConsumerState<JournalEntryEditorPage> createState() => _JournalEntryEditorPageState();
}

class _JournalEntryEditorPageState extends ConsumerState<JournalEntryEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _dateController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  List<JournalLineItem> _lines = [];
  
  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
    _lines = [
      JournalLineItem(accountId: '', debit: 0, credit: 0),
      JournalLineItem(accountId: '', debit: 0, credit: 0),
    ];
  }
  
  @override
  Widget build(BuildContext context) {
    final totalDebits = _lines.fold<int>(0, (sum, line) => sum + line.debit);
    final totalCredits = _lines.fold<int>(0, (sum, line) => sum + line.credit);
    final isBalanced = totalDebits == totalCredits && totalDebits > 0;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entryId == null ? '新建凭证' : '编辑凭证'),
        actions: [
          TextButton.icon(
            onPressed: isBalanced ? _saveEntry : null,
            icon: const Icon(Icons.save),
            label: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Date field
            TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: '日期',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: _selectDate,
            ),
            
            const SizedBox(height: 16),
            
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '摘要',
                hintText: '输入凭证摘要',
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 16),
            
            // Reference
            TextFormField(
              controller: _referenceController,
              decoration: const InputDecoration(
                labelText: '参考号',
                hintText: '发票号、收据号等',
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Lines header
            Row(
              children: [
                Text(
                  '分录行',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addLine,
                  tooltip: '添加行',
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Lines
            ...List.generate(_lines.length, (index) => _buildLineCard(index)),
            
            const SizedBox(height: 24),
            
            // Balance indicator
            _buildBalanceCard(context, totalDebits, totalCredits, isBalanced),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLineCard(int index) {
    final line = _lines[index];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('行 ${index + 1}'),
                const Spacer(),
                if (_lines.length > 2)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeLine(index),
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Account selector (placeholder)
            TextFormField(
              decoration: const InputDecoration(
                labelText: '科目',
                hintText: '选择会计科目',
                suffixIcon: Icon(Icons.search),
              ),
              readOnly: true,
              onTap: () {
                // Show account selector
              },
            ),
            
            const SizedBox(height: 8),
            
            // Debit and credit
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: line.debit > 0 ? line.debit.toString() : '',
                    decoration: const InputDecoration(
                      labelText: '借方',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _lines[index] = line.copyWith(
                          debit: int.tryParse(value) ?? 0,
                          credit: 0,
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: line.credit > 0 ? line.credit.toString() : '',
                    decoration: const InputDecoration(
                      labelText: '贷方',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _lines[index] = line.copyWith(
                          credit: int.tryParse(value) ?? 0,
                          debit: 0,
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBalanceCard(
    BuildContext context,
    int totalDebits,
    int totalCredits,
    bool isBalanced,
  ) {
    final difference = (totalDebits - totalCredits).abs();
    
    return Card(
      color: isBalanced
          ? Colors.green.withOpacity(0.1)
          : Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('借方合计', style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      '¥${(totalDebits / 100).toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text('贷方合计', style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      '¥${(totalCredits / 100).toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isBalanced ? Icons.check_circle : Icons.error_outline,
                  color: isBalanced ? Colors.green : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  isBalanced
                      ? '凭证平衡'
                      : '差额: ¥${(difference / 100).toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isBalanced ? Colors.green : Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }
  
  void _addLine() {
    setState(() {
      _lines.add(JournalLineItem(accountId: '', debit: 0, credit: 0));
    });
  }
  
  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index);
    });
  }
  
  void _saveEntry() {
    if (!_formKey.currentState!.validate()) return;
    
    // Save entry
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('凭证已保存'),
        backgroundColor: Colors.green,
      ),
    );
    
    Navigator.pop(context);
  }
  
  @override
  void dispose() {
    _dateController.dispose();
    _descriptionController.dispose();
    _referenceController.dispose();
    super.dispose();
  }
}

/// Model for a journal line item in the editor.
class JournalLineItem {
  final String accountId;
  final int debit;
  final int credit;
  final String? description;
  
  const JournalLineItem({
    required this.accountId,
    required this.debit,
    required this.credit,
    this.description,
  });
  
  JournalLineItem copyWith({
    String? accountId,
    int? debit,
    int? credit,
    String? description,
  }) {
    return JournalLineItem(
      accountId: accountId ?? this.accountId,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      description: description ?? this.description,
    );
  }
}