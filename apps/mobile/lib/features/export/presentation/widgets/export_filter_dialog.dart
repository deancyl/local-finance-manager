import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:database/database.dart';
import '../../data/export_service.dart';

/// Dialog for setting export filters
class ExportFilterDialog extends StatefulWidget {
  final ExportFilters initialFilters;
  final List<Account> accounts;
  final List<Category> categories;

  const ExportFilterDialog({
    super.key,
    required this.initialFilters,
    required this.accounts,
    required this.categories,
  });

  @override
  State<ExportFilterDialog> createState() => _ExportFilterDialogState();
}

class _ExportFilterDialogState extends State<ExportFilterDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _categoryId;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialFilters.startDate;
    _endDate = widget.initialFilters.endDate;
    _categoryId = widget.initialFilters.categoryId;
    _accountId = widget.initialFilters.accountId;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导出筛选'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date range section
            Text(
              '日期范围',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),

            // Start date
            ListTile(
              dense: true,
              leading: const Icon(Icons.calendar_today, size: 20),
              title: const Text('开始日期'),
              subtitle: Text(
                _startDate != null
                    ? DateFormat('yyyy-MM-dd').format(_startDate!)
                    : '不限',
              ),
              trailing: _startDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _startDate = null;
                        });
                      },
                    )
                  : null,
              onTap: () => _selectStartDate(),
            ),

            // End date
            ListTile(
              dense: true,
              leading: const Icon(Icons.calendar_today, size: 20),
              title: const Text('结束日期'),
              subtitle: Text(
                _endDate != null
                    ? DateFormat('yyyy-MM-dd').format(_endDate!)
                    : '不限',
              ),
              trailing: _endDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _endDate = null;
                        });
                      },
                    )
                  : null,
              onTap: () => _selectEndDate(),
            ),

            const SizedBox(height: 16),

            // Account filter
            Text(
              '账户',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),

            DropdownButtonFormField<String?>(
              value: _accountId,
              decoration: const InputDecoration(
                hintText: '全部账户',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('全部账户')),
                ...widget.accounts.map(
                  (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _accountId = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // Category filter
            Text(
              '分类',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),

            DropdownButtonFormField<String?>(
              value: _categoryId,
              decoration: const InputDecoration(
                hintText: '全部分类',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('全部分类')),
                ...widget.categories.map(
                  (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _categoryId = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => _clearFilters(),
          child: const Text('清除'),
        ),
        ElevatedButton(
          onPressed: () => _applyFilters(),
          child: const Text('应用'),
        ),
      ],
    );
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: _endDate ?? DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _categoryId = null;
      _accountId = null;
    });
  }

  void _applyFilters() {
    final filters = ExportFilters(
      startDate: _startDate,
      endDate: _endDate,
      categoryId: _categoryId,
      accountId: _accountId,
    );

    Navigator.pop(context, filters);
  }
}
