import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:core/core.dart';
import 'llm_provider.dart';

/// Ollama LLM provider for local AI inference.
///
/// Connects to a local Ollama server for AI-powered features.
/// Supports various models like llama3, mistral, qwen, etc.
class OllamaProvider implements LlmProvider {
  final Logger _log = Logger('OllamaProvider');

  /// Base URL of the Ollama server.
  final String baseUrl;

  /// Model to use for inference.
  final String model;

  /// HTTP client for API requests.
  final http.Client _client;

  /// Timeout for API requests.
  final Duration timeout;

  OllamaProvider({
    this.baseUrl = 'http://localhost:11434',
    this.model = 'qwen2.5:3b',
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  @override
  String get name => 'Ollama ($model)';

  @override
  Future<bool> checkAvailability() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/tags'))
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final models = data['models'] as List<dynamic>? ?? [];

        // Check if the requested model is available
        final hasModel = models.any((m) => (m['name'] as String?)?.contains(model) ?? false);
        
        if (!hasModel) {
          _log.warning('Model $model not found in Ollama. Available models: ${models.map((m) => m['name']).join(', ')}');
        }

        return hasModel;
      }

      return false;
    } catch (e) {
      _log.fine('Ollama not available: $e');
      return false;
    }
  }

  @override
  Future<CategorySuggestion?> suggestCategory({
    required Transaction transaction,
    required List<Category> availableCategories,
  }) async {
    if (transaction.description == null || transaction.description!.isEmpty) {
      return null;
    }

    try {
      final prompt = _buildCategorizationPrompt(
        transaction: transaction,
        availableCategories: availableCategories,
      );

      final response = await _generateCompletion(prompt);

      if (response == null) {
        return null;
      }

      return _parseCategorySuggestion(response, availableCategories);
    } catch (e, st) {
      _log.warning('Error getting category suggestion from Ollama', e, st);
      return null;
    }
  }

  /// Generate a completion using the Ollama API.
  Future<String?> _generateCompletion(String prompt) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'prompt': prompt,
              'stream': false,
              'options': {
                'temperature': 0.3,
                'top_p': 0.9,
                'num_predict': 100,
              },
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['response'] as String?;
      }

      return null;
    } catch (e) {
      _log.fine('Error generating completion: $e');
      return null;
    }
  }

  /// Build a categorization prompt for the LLM.
  String _buildCategorizationPrompt({
    required Transaction transaction,
    required List<Category> availableCategories,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('你是一个金融交易分类助手。请根据交易描述选择最合适的分类。');
    buffer.writeln();
    buffer.writeln('交易信息:');
    buffer.writeln('- 描述: ${transaction.description}');
    buffer.writeln('- 金额: ${transaction.notes ?? "未知"}');
    buffer.writeln('- 日期: ${transaction.postDate}');
    buffer.writeln();
    buffer.writeln('可选分类:');
    for (final category in availableCategories) {
      final type = category.isIncome ? '收入' : '支出';
      buffer.writeln('- ${category.id}: ${category.name} ($type)');
    }
    buffer.writeln();
    buffer.writeln('请仅返回JSON格式: {"categoryId": "分类ID", "confidence": 置信度}');

    return buffer.toString();
  }

  /// Parse the LLM response into a CategorySuggestion.
  CategorySuggestion? _parseCategorySuggestion(
    String response,
    List<Category> availableCategories,
  ) {
    try {
      // Try to extract JSON from the response
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(response);
      if (jsonMatch == null) {
        return null;
      }

      final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      final categoryId = json['categoryId'] as String?;
      final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.5;

      if (categoryId == null) {
        return null;
      }

      // Verify the category exists
      final exists = availableCategories.any((c) => c.id == categoryId);
      if (!exists) {
        _log.fine('LLM suggested non-existent category: $categoryId');
        return null;
      }

      return CategorySuggestion(
        categoryId: categoryId,
        confidence: confidence.clamp(0.0, 1.0),
        reasoning: json['reasoning'] as String?,
      );
    } catch (e) {
      _log.fine('Error parsing category suggestion: $e');
      return null;
    }
  }

  /// Analyze spending patterns and provide insights.
  Future<SpendingInsights?> analyzeSpendingPatterns({
    required List<Transaction> transactions,
    required List<Category> categories,
  }) async {
    if (transactions.isEmpty) {
      return null;
    }

    try {
      final prompt = _buildSpendingAnalysisPrompt(transactions: transactions, categories: categories);
      final response = await _generateCompletion(prompt);

      if (response == null) {
        return null;
      }

      return _parseSpendingInsights(response);
    } catch (e, st) {
      _log.warning('Error analyzing spending patterns', e, st);
      return null;
    }
  }

  /// Build a spending analysis prompt.
  String _buildSpendingAnalysisPrompt({
    required List<Transaction> transactions,
    required List<Category> categories,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('你是一个个人财务分析师。请分析以下交易数据并提供洞察。');
    buffer.writeln();
    buffer.writeln('交易数据 (最近${transactions.length}笔):');

    // Group transactions by category
    final byCategory = <String, List<Transaction>>{};
    for (final t in transactions) {
      final catId = t.categoryId ?? 'uncategorized';
      byCategory.putIfAbsent(catId, () => []).add(t);
    }

    for (final entry in byCategory.entries) {
      final category = categories.firstWhere(
        (c) => c.id == entry.key,
        orElse: () => Category(id: entry.key, name: '未分类', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      );
      final total = entry.value.fold(0.0, (sum, t) => sum + (t.notes?.toDouble() ?? 0));
      buffer.writeln('- ${category.name}: ${entry.value.length}笔, 总计: $total');
    }

    buffer.writeln();
    buffer.writeln('请分析并返回JSON格式:');
    buffer.writeln('{"topSpendingCategories": ["分类1", "分类2"], "anomalies": ["异常1"], "recommendations": ["建议1"], "summary": "总结"}');

    return buffer.toString();
  }

  /// Parse spending insights from LLM response.
  SpendingInsights? _parseSpendingInsights(String response) {
    try {
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(response);
      if (jsonMatch == null) {
        return null;
      }

      final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;

      return SpendingInsights(
        topSpendingCategories: (json['topSpendingCategories'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [],
        anomalies: (json['anomalies'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [],
        recommendations: (json['recommendations'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [],
        summary: json['summary'] as String?,
      );
    } catch (e) {
      _log.fine('Error parsing spending insights: $e');
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    _client.close();
  }
}

/// Spending insights from AI analysis.
class SpendingInsights {
  /// Top spending categories by amount.
  final List<String> topSpendingCategories;

  /// Detected anomalies or unusual patterns.
  final List<String> anomalies;

  /// AI-generated recommendations.
  final List<String> recommendations;

  /// Summary of the analysis.
  final String? summary;

  const SpendingInsights({
    this.topSpendingCategories = const [],
    this.anomalies = const [],
    this.recommendations = const [],
    this.summary,
  });
}
