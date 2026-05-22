/// AI integration package for local finance manager.
///
/// Provides AI-powered features with graceful degradation:
/// - Transaction categorization
/// - Spending pattern analysis
/// - Budget recommendations
///
/// All features work with local LLM services (Ollama, llama.cpp)
/// and gracefully degrade when AI is unavailable.
library ai;

export 'src/ai_service.dart';
export 'src/categorization/categorizer.dart';
export 'src/providers/llm_provider.dart';
export 'src/providers/mock_llm_provider.dart';
