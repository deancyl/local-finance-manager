import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ai/ai.dart';
import 'data/ai_provider.dart';
import '../../transactions/data/transaction_provider.dart';
import '../../categories/data/category_provider.dart';

/// Page for AI-powered spending analysis and insights.
class AiInsightsPage extends ConsumerStatefulWidget {
  const AiInsightsPage({super.key});

  @override
  ConsumerState<AiInsightsPage> createState() => _AiInsightsPageState();
}

class _AiInsightsPageState extends ConsumerState<AiInsightsPage> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    // Set default date range to last 30 days
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30)),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateRange = DateTimeRange(
          start: picked.start,
          end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAvailable = ref.watch(aiAvailabilityProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 智能分析'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: '选择日期范围',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status banner
          if (!isAvailable)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(Icons.warning, color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI 服务不可用。请确保 Ollama 正在运行。',
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),

          // Date range indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(Icons.date_range, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('yyyy-MM-dd').format(_dateRange.start)} 至 ${DateFormat('yyyy-MM-dd').format(_dateRange.end)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: isAvailable
                ? _buildInsightsContent()
                : _buildUnavailableState(),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsContent() {
    final insightsAsync = ref.watch(spendingInsightsProvider(_dateRange));

    return insightsAsync.when(
      data: (insights) {
        if (insights == null || insights.isEmpty) {
          return _buildEmptyState();
        }
        return _buildInsights(insights);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('分析失败: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(spendingInsightsProvider(_dateRange)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsights(SpendingInsights insights) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          if (insights.summary != null) ...[
            _SummaryCard(summary: insights.summary!),
            const SizedBox(height: 16),
          ],

          // Top spending categories
          if (insights.topSpendingCategories.isNotEmpty) ...[
            _InsightSection(
              title: '主要支出分类',
              icon: Icons.pie_chart,
              color: Colors.blue,
              items: insights.topSpendingCategories,
            ),
            const SizedBox(height: 16),
          ],

          // Anomalies
          if (insights.anomalies.isNotEmpty) ...[
            _InsightSection(
              title: '异常检测',
              icon: Icons.warning_amber,
              color: Colors.orange,
              items: insights.anomalies,
            ),
            const SizedBox(height: 16),
          ],

          // Recommendations
          if (insights.recommendations.isNotEmpty) ...[
            _InsightSection(
              title: '改进建议',
              icon: Icons.lightbulb,
              color: Colors.green,
              items: insights.recommendations,
            ),
            const SizedBox(height: 16),
          ],

          // Confidence indicator
          _ConfidenceIndicator(confidence: insights.confidence),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.analytics_outlined, size: 64),
          const SizedBox(height: 16),
          Text(
            '暂无分析数据',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text('请确保所选日期范围内有交易记录'),
        ],
      ),
    );
  }

  Widget _buildUnavailableState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.psychology_outlined, size: 64),
          const SizedBox(height: 16),
          Text(
            'AI 分析需要 Ollama 服务',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text('请启动 Ollama 并确保模型已下载'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.read(aiServiceProvider).checkAvailability(),
            icon: const Icon(Icons.refresh),
            label: const Text('检查连接'),
          ),
        ],
      ),
    );
  }
}

/// Provider for spending insights.
final spendingInsightsProvider = FutureProvider.family<SpendingInsights?, DateTimeRange>((ref, dateRange) async {
  final aiService = ref.watch(aiServiceProvider);
  final isAvailable = ref.watch(aiAvailabilityProvider).valueOrNull ?? false;

  if (!isAvailable) {
    return null;
  }

  // Get transactions for the date range
  final db = ref.watch(databaseProvider);
  final transactionsData = await db.transactionsDao.getTransactionsForDateRange(
    dateRange.start.millisecondsSinceEpoch,
    dateRange.end.millisecondsSinceEpoch,
  );

  // Convert to core Transaction model
  final transactions = transactionsData.map((t) => Transaction(
    id: t.id,
    description: t.description,
    notes: t.notes,
    postDate: DateTime.fromMillisecondsSinceEpoch(t.postDate),
    createdAt: DateTime.fromMillisecondsSinceEpoch(t.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(t.updatedAt),
  )).toList();

  // Get categories
  final categories = await ref.watch(allCategoriesProvider.future);

  // Get insights
  return await aiService.analyzeSpendingPatterns(
    transactions: transactions,
    categories: categories,
  );
});

/// Summary card widget.
class _SummaryCard extends StatelessWidget {
  final String summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '分析总结',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              summary,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Insight section widget.
class _InsightSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _InsightSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

/// Confidence indicator widget.
class _ConfidenceIndicator extends StatelessWidget {
  final double confidence;

  const _ConfidenceIndicator({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (confidence * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '分析置信度',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '$percentage%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: confidence >= 0.7 ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: confidence,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                confidence >= 0.7 ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
