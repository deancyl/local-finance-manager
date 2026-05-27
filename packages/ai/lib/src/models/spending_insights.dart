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

  /// Confidence of the analysis (0.0 to 1.0).
  final double confidence;

  const SpendingInsights({
    this.topSpendingCategories = const [],
    this.anomalies = const [],
    this.recommendations = const [],
    this.summary,
    this.confidence = 0.5,
  });

  /// Whether the insights are empty.
  bool get isEmpty =>
      topSpendingCategories.isEmpty &&
      anomalies.isEmpty &&
      recommendations.isEmpty &&
      summary == null;

  /// Whether the insights are not empty.
  bool get isNotEmpty => !isEmpty;
}

/// Budget recommendation from AI analysis.
class BudgetRecommendation {
  /// Category ID for the recommendation.
  final String categoryId;

  /// Category name.
  final String categoryName;

  /// Recommended budget amount.
  final double recommendedAmount;

  /// Current spending in this category.
  final double currentSpending;

  /// Reasoning for the recommendation.
  final String? reasoning;

  /// Priority level (1-5, 5 being highest).
  final int priority;

  const BudgetRecommendation({
    required this.categoryId,
    required this.categoryName,
    required this.recommendedAmount,
    required this.currentSpending,
    this.reasoning,
    this.priority = 3,
  });

  /// Whether the budget is over the recommendation.
  bool get isOverBudget => currentSpending > recommendedAmount;

  /// Percentage of budget used.
  double get usagePercentage =>
      recommendedAmount > 0 ? (currentSpending / recommendedAmount) * 100 : 0;
}

/// Transaction anomaly detection result.
class TransactionAnomaly {
  /// Transaction ID.
  final String transactionId;

  /// Type of anomaly detected.
  final AnomalyType type;

  /// Severity of the anomaly (1-5, 5 being most severe).
  final int severity;

  /// Description of the anomaly.
  final String description;

  /// Suggested action.
  final String? suggestedAction;

  const TransactionAnomaly({
    required this.transactionId,
    required this.type,
    required this.severity,
    required this.description,
    this.suggestedAction,
  });
}

/// Types of transaction anomalies.
enum AnomalyType {
  /// Unusual amount compared to history.
  unusualAmount,

  /// Duplicate transaction detected.
  duplicate,

  /// Unusual category for this merchant.
  unusualCategory,

  /// Unusual time of transaction.
  unusualTime,

  /// Unusual frequency of transactions.
  unusualFrequency,

  /// Potentially fraudulent.
  potentialFraud,
}
