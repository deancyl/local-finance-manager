import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:database/database.dart';
import '../../data/tag_provider.dart';

/// Tag selector widget with auto-complete functionality.
/// 
/// Features:
/// - Search existing tags by name
/// - Multi-select with visual chips
/// - Inline tag creation when tag doesn't exist
/// - Shows transaction count for each tag
class TagAutocompleteSelector extends ConsumerStatefulWidget {
  /// The transaction ID for loading existing tags (for edit mode).
  final String? transactionId;
  
  /// Initial selected tag IDs (for create mode).
  final List<String>? initialTagIds;
  
  /// Callback when selected tags change.
  final void Function(List<String> tagIds)? onChanged;
  
  /// Whether to show transaction count statistics.
  final bool showStatistics;

  const TagAutocompleteSelector({
    super.key,
    this.transactionId,
    this.initialTagIds,
    this.onChanged,
    this.showStatistics = false,
  });

  @override
  ConsumerState<TagAutocompleteSelector> createState() => _TagAutocompleteSelectorState();
}

class _TagAutocompleteSelectorState extends ConsumerState<TagAutocompleteSelector> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Set<String> _selectedTagIds = {};
  bool _initialized = false;
  bool _showSuggestions = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.initialTagIds != null) {
      _selectedTagIds = Set.from(widget.initialTagIds!);
      _initialized = true;
    }
    
    _focusNode.addListener(() {
      setState(() => _showSuggestions = _focusNode.hasFocus);
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allTagsAsync = ref.watch(allTagsProvider);
    final statsAsync = widget.showStatistics ? ref.watch(tagsWithStatsProvider) : null;
    
    // If we have a transactionId, watch its tags
    if (widget.transactionId != null && !_initialized) {
      final transactionTagsAsync = ref.watch(transactionTagsProvider(widget.transactionId!));
      transactionTagsAsync.whenData((tags) {
        if (!_initialized) {
          _selectedTagIds = Set.from(tags.map((t) => t.id));
          _initialized = true;
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '标签',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        
        // Search input with autocomplete
        TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: '搜索或创建标签...',
            prefixIcon: const Icon(Icons.tag),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: '创建新标签',
                    onPressed: () => _createNewTag(_searchController.text.trim()),
                  )
                : null,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: (_) => setState(() {}),
        ),
        
        // Suggestions dropdown
        if (_showSuggestions) ...[
          const SizedBox(height: 4),
          _buildSuggestionsDropdown(allTagsAsync, statsAsync),
        ],
        
        const SizedBox(height: 12),
        
        // Selected tags chips
        if (_selectedTagIds.isNotEmpty) ...[
          Text(
            '已选择 ${_selectedTagIds.length} 个标签',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildSelectedChips(allTagsAsync),
          ),
        ],
      ],
    );
  }

  Widget _buildSuggestionsDropdown(
    AsyncValue<List<Tag>> allTagsAsync,
    AsyncValue<List<(Tag, int)>>? statsAsync,
  ) {
    final searchQuery = _searchController.text.toLowerCase().trim();
    
    return allTagsAsync.when(
      data: (allTags) {
        // Filter tags by search query
        final filteredTags = searchQuery.isEmpty
            ? allTags
            : allTags.where((t) => t.name.toLowerCase().contains(searchQuery)).toList();
        
        // Exclude already selected tags
        final availableTags = filteredTags
            .where((t) => !_selectedTagIds.contains(t.id))
            .toList();
        
        if (availableTags.isEmpty) {
          if (searchQuery.isNotEmpty) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline, 
                    size: 20, 
                    color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('创建新标签 "$searchQuery"'),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _createNewTag(searchQuery),
                    child: const Text('创建'),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }
        
        return Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: availableTags.length,
            itemBuilder: (context, index) {
              final tag = availableTags[index];
              final count = widget.showStatistics && statsAsync != null
                  ? statsAsync.whenOrNull(
                      data: (stats) {
                        final stat = stats.where((s) => s.$1.id == tag.id).firstOrNull;
                        return stat?.$2 ?? 0;
                      },
                    ) ?? 0
                  : tag.usageCount;
              
              return _buildSuggestionItem(tag, count);
            },
          ),
        );
      },
      loading: () => const Center(child: SizedBox(height: 40, child: CircularProgressIndicator())),
      error: (error, _) => Text('加载失败: $error'),
    );
  }

  Widget _buildSuggestionItem(Tag tag, int count) {
    final color = _parseColor(tag.color);
    
    return ListTile(
      dense: true,
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      title: Text('#${tag.name}'),
      subtitle: widget.showStatistics && count > 0
          ? Text('使用 $count 次', style: Theme.of(context).textTheme.bodySmall)
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.add_circle_outline),
        onPressed: () => _selectTag(tag),
      ),
      onTap: () => _selectTag(tag),
    );
  }

  List<Widget> _buildSelectedChips(AsyncValue<List<Tag>> allTagsAsync) {
    return allTagsAsync.when(
      data: (allTags) {
        final selectedTags = allTags
            .where((t) => _selectedTagIds.contains(t.id))
            .toList();
        
        return selectedTags.map((tag) => _buildSelectedChip(tag)).toList();
      },
      loading: () => [const CircularProgressIndicator()],
      error: (_, __) => [],
    );
  }

  Widget _buildSelectedChip(Tag tag) {
    final color = _parseColor(tag.color);
    
    return InputChip(
      label: Text('#${tag.name}'),
      avatar: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      selected: true,
      selectedColor: color.withOpacity(0.2),
      deleteIcon: Icon(Icons.close, size: 18, color: color),
      onDeleted: () => _removeTag(tag.id),
      onPressed: () => _removeTag(tag.id),
      side: BorderSide(color: color),
      labelStyle: TextStyle(color: color),
    );
  }

  void _selectTag(Tag tag) {
    setState(() {
      _selectedTagIds.add(tag.id);
      _searchController.clear();
    });
    widget.onChanged?.call(_selectedTagIds.toList());
  }

  void _removeTag(String tagId) {
    setState(() {
      _selectedTagIds.remove(tagId);
    });
    widget.onChanged?.call(_selectedTagIds.toList());
  }

  Future<void> _createNewTag(String name) async {
    if (name.isEmpty) return;
    
    await ref.read(tagNotifierProvider.notifier).createTag(
      name: name,
      color: '#607D8B', // Default color, user can edit later
    );
    
    // Find the newly created tag and select it
    final allTags = await ref.read(allTagsProvider.future);
    final newTag = allTags.firstWhere(
      (t) => t.name == name,
      orElse: () => allTags.last,
    );
    
    setState(() {
      _selectedTagIds.add(newTag.id);
      _searchController.clear();
    });
    widget.onChanged?.call(_selectedTagIds.toList());
  }
  Color _parseColor(String colorHex) {
    final colorValue = int.tryParse(colorHex.replaceFirst('#', '0xFF'));
    return colorValue != null ? Color(colorValue) : Colors.grey;
  }
  }
}