import 'package:test/test.dart';
import 'package:ai/ai.dart';
import 'package:core/core.dart';

void main() {
  group('AiService', () {
    late AiService service;
    late MockLlmProvider mockProvider;

    setUp(() {
      mockProvider = MockLlmProvider();
      service = AiService(provider: mockProvider);
    });

    tearDown(() async {
      await service.dispose();
    });

    test('isAvailable is false initially', () {
      expect(service.isAvailable, isFalse);
    });

    test('checkAvailability returns false with default mock provider', () async {
      final available = await service.checkAvailability();
      expect(available, isFalse);
      expect(service.isAvailable, isFalse);
    });

    test('checkAvailability returns true when simulateAvailable is true',
        () async {
      final availableProvider = MockLlmProvider(simulateAvailable: true);
      final availableService = AiService(provider: availableProvider);

      try {
        final available = await availableService.checkAvailability();
        expect(available, isTrue);
        expect(availableService.isAvailable, isTrue);
      } finally {
        await availableService.dispose();
      }
    });

    test('suggestCategory returns null when LLM is not available', () async {
      final transaction = Transaction(
        description: 'Starbucks Coffee',
        postDate: DateTime.now(),
        commodityId: 'CNY',
      );

      final categories = [
        Category(name: 'Food & Dining', isIncome: false),
        Category(name: 'Transportation', isIncome: false),
      ];

      final suggestion = await service.suggestCategory(
        transaction: transaction,
        availableCategories: categories,
      );

      expect(suggestion, isNull);
    });

    test('suggestCategory returns null for transaction without description',
        () async {
      final availableProvider = MockLlmProvider(simulateAvailable: true);
      final availableService = AiService(provider: availableProvider);

      try {
        final transaction = Transaction(
          description: null,
          postDate: DateTime.now(),
          commodityId: 'CNY',
        );

        final categories = [Category(name: 'Food & Dining')];

        final suggestion = await availableService.suggestCategory(
          transaction: transaction,
          availableCategories: categories,
        );

        expect(suggestion, isNull);
      } finally {
        await availableService.dispose();
      }
    });

    test('suggestCategory returns null when no categories provided', () async {
      final availableProvider = MockLlmProvider(simulateAvailable: true);
      final availableService = AiService(provider: availableProvider);

      try {
        final transaction = Transaction(
          description: 'Starbucks Coffee',
          postDate: DateTime.now(),
          commodityId: 'CNY',
        );

        final suggestion = await availableService.suggestCategory(
          transaction: transaction,
          availableCategories: [],
        );

        expect(suggestion, isNull);
      } finally {
        await availableService.dispose();
      }
    });

    test('availabilityStream emits changes', () async {
      final availableProvider = MockLlmProvider(simulateAvailable: true);
      final availableService = AiService(provider: availableProvider);

      try {
        final availabilityFuture =
            availableService.availabilityStream.first;

        await availableService.checkAvailability();

        final emitted = await availabilityFuture.timeout(
          const Duration(seconds: 1),
          onTimeout: () => false,
        );

        expect(emitted, isTrue);
      } finally {
        await availableService.dispose();
      }
    });
  });

  group('Categorizer', () {
    late Categorizer categorizer;

    setUp(() {
      categorizer = Categorizer();
    });

    test('cleanDescription returns empty string for null input', () {
      expect(categorizer.cleanDescription(null), isEmpty);
    });

    test('cleanDescription returns empty string for empty input', () {
      expect(categorizer.cleanDescription(''), isEmpty);
    });

    test('cleanDescription removes transaction IDs', () {
      final result = categorizer
          .cleanDescription('支付宝交易号：2024010112345678 星巴克咖啡');
      expect(result.contains('交易号'), isFalse);
      expect(result.contains('星巴克咖啡'), isTrue);
    });

    test('cleanDescription removes card number masks', () {
      final result =
          categorizer.cleanDescription('尾号1234 星巴克咖啡 店)');
      expect(result.contains('尾号'), isFalse);
      expect(result.contains('星巴克咖啡'), isTrue);
    });

    test('cleanDescription removes common prefixes', () {
      final result = categorizer.cleanDescription('支付宝-星巴克咖啡');
      expect(result.contains('支付宝'), isFalse);
      expect(result.contains('星巴克咖啡'), isTrue);
    });

    test('cleanDescription collapses multiple spaces', () {
      final result = categorizer.cleanDescription('星巴克   咖啡');
      expect(result.contains('  '), isFalse);
      expect(result, equals('星巴克 咖啡'));
    });

    test('extractKeywords returns empty list for null input', () {
      expect(categorizer.extractKeywords(null), isEmpty);
    });

    test('extractKeywords returns meaningful words', () {
      final keywords =
          categorizer.extractKeywords('星巴克咖啡 门店消费');
      expect(keywords, containsAll(['星巴克咖啡', '门店消费']));
    });

    test('extractKeywords filters short words', () {
      final keywords = categorizer.extractKeywords('星巴克 咖啡 店');
      expect(keywords, isNot(contains('店')));
    });

    test('extractKeywords filters numeric-only words', () {
      final keywords = categorizer.extractKeywords('星巴克 1234 咖啡');
      expect(keywords, isNot(contains('1234')));
    });

    test('buildCategorizationPrompt includes transaction details', () {
      final transaction = Transaction(
        description: 'Starbucks Coffee',
        postDate: DateTime(2024, 1, 1),
        commodityId: 'CNY',
      );

      final categories = [
        Category(id: 'cat1', name: 'Food & Dining', isIncome: false),
        Category(id: 'cat2', name: 'Salary', isIncome: true),
      ];

      final prompt = categorizer.buildCategorizationPrompt(
        transaction: transaction,
        availableCategories: categories,
      );

      expect(prompt.contains('Starbucks Coffee'), isTrue);
      expect(prompt.contains('cat1'), isTrue);
      expect(prompt.contains('Food & Dining'), isTrue);
      expect(prompt.contains('[支出]'), isTrue);
      expect(prompt.contains('[收入]'), isTrue);
    });
  });

  group('MockLlmProvider', () {
    test('name returns correct value', () {
      final provider = MockLlmProvider();
      expect(provider.name, equals('Mock LLM Provider'));
    });

    test('checkAvailability returns false by default', () async {
      final provider = MockLlmProvider();
      final available = await provider.checkAvailability();
      expect(available, isFalse);
    });

    test('checkAvailability returns true when simulateAvailable is true',
        () async {
      final provider = MockLlmProvider(simulateAvailable: true);
      final available = await provider.checkAvailability();
      expect(available, isTrue);
    });

    test('suggestCategory returns null by default', () async {
      final provider = MockLlmProvider();
      final transaction = Transaction(
        description: 'Test',
        postDate: DateTime.now(),
        commodityId: 'CNY',
      );

      final suggestion = await provider.suggestCategory(
        transaction: transaction,
        availableCategories: [Category(name: 'Test')],
      );

      expect(suggestion, isNull);
    });

    test('suggestCategory returns preset suggestion when available', () async {
      final categoryId = 'cat-123';
      final provider = MockLlmProvider(
        simulateAvailable: true,
        presetSuggestions: {
          'starbucks coffee': CategorySuggestion(
            categoryId: categoryId,
            confidence: 0.9,
          ),
        },
      );

      final transaction = Transaction(
        description: 'Starbucks Coffee',
        postDate: DateTime.now(),
        commodityId: 'CNY',
      );

      final suggestion = await provider.suggestCategory(
        transaction: transaction,
        availableCategories: [Category(id: categoryId, name: 'Food')],
      );

      expect(suggestion, isNotNull);
      expect(suggestion!.categoryId, equals(categoryId));
      expect(suggestion.confidence, equals(0.9));
    });

    test('dispose completes without error', () async {
      final provider = MockLlmProvider();
      await expectLater(provider.dispose(), completes);
    });
  });

  group('CategorySuggestion', () {
    test('props include all fields', () {
      final suggestion = CategorySuggestion(
        categoryId: 'cat-1',
        confidence: 0.85,
        reasoning: 'Test reasoning',
      );

      expect(
        suggestion.props,
        equals(['cat-1', 0.85, 'Test reasoning']),
      );
    });

    test('equality works correctly', () {
      final suggestion1 = CategorySuggestion(
        categoryId: 'cat-1',
        confidence: 0.85,
      );

      final suggestion2 = CategorySuggestion(
        categoryId: 'cat-1',
        confidence: 0.85,
      );

      expect(suggestion1, equals(suggestion2));
    });
  });
}
