import 'package:flutter/material.dart';

/// Field mapping dialog for manual column mapping when auto-detection fails.
/// 
/// Allows users to specify which CSV column maps to which transaction field.
class FieldMappingDialog extends StatefulWidget {
  /// Column headers from the CSV file.
  final List<String> columns;
  
  /// Preview rows to show sample data.
  final List<Map<String, dynamic>> previewRows;
  
  /// Initial field mapping (if any).
  final Map<String, String> initialMapping;
  
  /// Fields available for mapping.
  static const List<MapEntry<String, String>> availableFields = [
    MapEntry('date', '日期'),
    MapEntry('amount', '金额'),
    MapEntry('description', '描述'),
    MapEntry('category', '分类'),
    MapEntry('account', '账户'),
    MapEntry('reference', '参考号'),
    MapEntry('balance', '余额'),
    MapEntry('counterparty', '对方账户'),
    MapEntry('note', '备注'),
  ];

  const FieldMappingDialog({
    super.key,
    required this.columns,
    required this.previewRows,
    this.initialMapping = const {},
  });

  @override
  State<FieldMappingDialog> createState() => _FieldMappingDialogState();
}

class _FieldMappingDialogState extends State<FieldMappingDialog> {
  /// Mapping from column name to field name.
  late Map<String, String?> _columnMappings;
  
  /// Mapping from field name to column name (reverse lookup).
  Map<String, String> get _fieldToColumn => {
    for (var entry in _columnMappings.entries)
      if (entry.value != null) entry.value!: entry.key
  };

  @override
  void initState() {
    super.initState();
    // Initialize mappings from initialMapping or empty
    _columnMappings = {
      for (var column in widget.columns)
        column: widget.initialMapping[column]
    };
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 800,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInstructions(),
                    const SizedBox(height: 16),
                    _buildPreviewTable(),
                    const SizedBox(height: 24),
                    _buildMappingSection(),
                  ],
                ),
              ),
            ),
            const Divider(),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.map_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            '字段映射',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '自动检测失败，请手动指定每列对应的字段。至少需要映射日期和金额字段。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewTable() {
    if (widget.previewRows.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('无预览数据'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '数据预览（前5行）',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              columnSpacing: 24,
              columns: widget.columns.map((col) {
                final isMapped = _columnMappings[col] != null;
                return DataColumn(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          col,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isMapped 
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMapped) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              rows: widget.previewRows.take(5).map((row) {
                return DataRow(
                  cells: widget.columns.map((col) {
                    return DataCell(
                      Text(
                        row[col]?.toString() ?? '',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMappingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '字段映射',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        
        // Required fields section
        _buildRequiredFields(),
        const SizedBox(height: 16),
        
        // Optional fields section
        _buildOptionalFields(),
      ],
    );
  }

  Widget _buildRequiredFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '必填',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '至少需要日期和金额',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildFieldDropdown(
                fieldKey: 'date',
                fieldLabel: '日期',
                isRequired: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFieldDropdown(
                fieldKey: 'amount',
                fieldLabel: '金额',
                isRequired: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionalFields() {
    final optionalFields = FieldMappingDialog.availableFields
        .where((f) => f.key != 'date' && f.key != 'amount')
        .toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '可选',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: optionalFields.map((field) {
            return SizedBox(
              width: 200,
              child: _buildFieldDropdown(
                fieldKey: field.key,
                fieldLabel: field.value,
                isRequired: false,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFieldDropdown({
    required String fieldKey,
    required String fieldLabel,
    required bool isRequired,
  }) {
    final selectedColumn = _fieldToColumn[fieldKey];
    
    return DropdownButtonFormField<String?>(
      value: selectedColumn,
      decoration: InputDecoration(
        labelText: fieldLabel,
        border: const OutlineInputBorder(),
        isDense: true,
        prefixIcon: Icon(
          isRequired ? Icons.star : Icons.check_circle_outline,
          size: 18,
          color: isRequired 
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.outline,
        ),
      ),
      hint: const Text('选择列'),
      items: [
        const DropdownMenuItem(value: null, child: Text('不映射')),
        ...widget.columns.map((col) {
          final isAlreadyMapped = _columnMappings[col] != null && 
              _columnMappings[col] != fieldKey;
          return DropdownMenuItem(
            value: col,
            enabled: !isAlreadyMapped,
            child: Text(
              col,
              style: TextStyle(
                color: isAlreadyMapped 
                  ? Theme.of(context).colorScheme.outline
                  : null,
              ),
            ),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          // Clear previous mapping for this field
          if (selectedColumn != null) {
            _columnMappings[selectedColumn] = null;
          }
          
          // Set new mapping
          if (value != null) {
            _columnMappings[value] = fieldKey;
          }
        });
      },
    );
  }

  Widget _buildActions() {
    final hasDate = _fieldToColumn.containsKey('date');
    final hasAmount = _fieldToColumn.containsKey('amount');
    final canSave = hasDate && hasAmount;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: _autoDetect,
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('自动检测'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: canSave ? _saveMapping : null,
            icon: const Icon(Icons.check),
            label: const Text('保存映射'),
          ),
        ],
      ),
    );
  }

  void _autoDetect() {
    setState(() {
      _columnMappings = {};
      
      for (var column in widget.columns) {
        final lowerCol = column.toLowerCase();
        
        // Date detection
        if (lowerCol.contains('日期') || 
            lowerCol.contains('date') ||
            lowerCol.contains('时间') ||
            lowerCol.contains('time')) {
          _columnMappings[column] = 'date';
        }
        // Amount detection
        else if (lowerCol.contains('金额') || 
                 lowerCol.contains('amount') ||
                 lowerCol.contains('收入') ||
                 lowerCol.contains('支出')) {
          _columnMappings[column] = 'amount';
        }
        // Description detection
        else if (lowerCol.contains('描述') || 
                 lowerCol.contains('description') ||
                 lowerCol.contains('摘要') ||
                 lowerCol.contains('交易')) {
          _columnMappings[column] = 'description';
        }
        // Category detection
        else if (lowerCol.contains('分类') || 
                 lowerCol.contains('category') ||
                 lowerCol.contains('类型')) {
          _columnMappings[column] = 'category';
        }
        // Account detection
        else if (lowerCol.contains('账户') || 
                 lowerCol.contains('account')) {
          _columnMappings[column] = 'account';
        }
        // Balance detection
        else if (lowerCol.contains('余额') || 
                 lowerCol.contains('balance')) {
          _columnMappings[column] = 'balance';
        }
        // Reference detection
        else if (lowerCol.contains('参考') || 
                 lowerCol.contains('reference') ||
                 lowerCol.contains('订单') ||
                 lowerCol.contains('流水')) {
          _columnMappings[column] = 'reference';
        }
        // Counterparty detection
        else if (lowerCol.contains('对方') || 
                 lowerCol.contains('counterparty')) {
          _columnMappings[column] = 'counterparty';
        }
        // Note detection
        else if (lowerCol.contains('备注') || 
                 lowerCol.contains('note') ||
                 lowerCol.contains('说明')) {
          _columnMappings[column] = 'note';
        }
      }
    });
  }

  void _saveMapping() {
    // Build the mapping result (column -> field)
    final mapping = <String, String>{};
    for (var entry in _columnMappings.entries) {
      if (entry.value != null) {
        mapping[entry.key] = entry.value!;
      }
    }
    
    Navigator.pop(context, mapping);
  }
}
