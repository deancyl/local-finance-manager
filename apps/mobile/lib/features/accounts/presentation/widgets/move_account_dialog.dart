import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart';
import '../../data/account_provider.dart';

/// Dialog for moving an account to a new parent.
class MoveAccountDialog extends ConsumerStatefulWidget {
  final Account account;

  const MoveAccountDialog({super.key, required this.account});

  @override
  ConsumerState<MoveAccountDialog> createState() => _MoveAccountDialogState();
}

class _MoveAccountDialogState extends ConsumerState<MoveAccountDialog> {
  String? _selectedParentId;
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedParentId = widget.account.parentId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountsAsync = ref.watch(accountsProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.drive_file_move_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '移动账户',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '将 "${widget.account.name}" 移动到新位置',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            
            // Search field
            TextField(
              decoration: InputDecoration(
                hintText: '搜索父账户...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
            const SizedBox(height: 16),
            
            // Account list
            accountsAsync.when(
              data: (accounts) {
                // Filter eligible parents: same type, placeholder, not self, not descendant
                final eligibleParents = accounts
                    .where((a) => 
                        a.accountType == widget.account.accountType &&
                        a.isPlaceholder &&
                        !a.isHidden &&
                        a.id != widget.account.id &&
                        !_isDescendantOf(accounts, a.id, widget.account.id) &&
                        (_searchQuery.isEmpty || a.name.toLowerCase().contains(_searchQuery)))
                    .toList();
                
                if (eligibleParents.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        '没有可用的父账户',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }
                
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: eligibleParents.length + 1, // +1 for "Root" option
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Root option
                        return _buildParentOption(
                          context,
                          id: null,
                          name: '根级账户 (无父账户)',
                          icon: Icons.folder_open,
                          isSelected: _selectedParentId == null,
                          onTap: () => setState(() => _selectedParentId = null),
                        );
                      }
                      
                      final parent = eligibleParents[index - 1];
                      return _buildParentOption(
                        context,
                        id: parent.id,
                        name: parent.name,
                        code: parent.code,
                        icon: _getIconForAccount(parent.name),
                        isSelected: _selectedParentId == parent.id,
                        onTap: () => setState(() => _selectedParentId = parent.id),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('加载失败')),
            ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _isLoading ? null : _move,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('移动'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildParentOption(
    BuildContext context, {
    String? id,
    required String name,
    String? code,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final color = _getTypeColor(widget.account.accountType);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (code != null)
                    Text(
                      '代码: $code',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  /// Checks if targetId is a descendant of accountId (to prevent circular references).
  bool _isDescendantOf(List<Account> accounts, String targetId, String accountId) {
    // Walk up from targetId to see if we reach accountId
    String? currentId = targetId;
    final visited = <String>{};
    
    while (currentId != null) {
      if (visited.contains(currentId)) break; // Safety check
      visited.add(currentId);
      
      if (currentId == accountId) return true;
      
      final account = accounts.where((a) => a.id == currentId).firstOrNull;
      currentId = account?.parentId;
    }
    
    return false;
  }

  Future<void> _move() async {
    setState(() => _isLoading = true);
    
    try {
      await ref.read(accountNotifierProvider.notifier).moveAccount(
        accountId: widget.account.id,
        newParentId: _selectedParentId,
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('账户已移动')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移动失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getTypeColor(String accountType) {
    switch (accountType) {
      case 'ASSET':
        return Colors.green;
      case 'LIABILITY':
        return Colors.red;
      case 'INCOME':
        return Colors.blue;
      case 'EXPENSE':
        return Colors.orange;
      case 'EQUITY':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForAccount(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('银行') || lower.contains('bank')) return Icons.account_balance;
    if (lower.contains('现金') || lower.contains('cash')) return Icons.money;
    if (lower.contains('投资') || lower.contains('invest')) return Icons.trending_up;
    if (lower.contains('信用卡') || lower.contains('credit')) return Icons.credit_card;
    if (lower.contains('贷款') || lower.contains('loan')) return Icons.home;
    if (lower.contains('工资') || lower.contains('salary')) return Icons.work;
    if (lower.contains('日常') || lower.contains('daily')) return Icons.shopping_bag;
    if (lower.contains('交通') || lower.contains('transport')) return Icons.directions_car;
    if (lower.contains('娱乐') || lower.contains('entertainment')) return Icons.movie;
    if (lower.contains('医疗') || lower.contains('health')) return Icons.local_hospital;
    return Icons.folder;
  }
}