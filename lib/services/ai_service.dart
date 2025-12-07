import '../models/chat_message.dart';
import '../models/ai_provider.dart';

/// Abstract AI Service interface
/// All AI providers implement this interface
abstract class AIService {
  /// Send a message and get a complete response
  Future<String> sendMessage(
    String message,
    List<ChatMessage> history, {
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 2048,
  });

  /// Send a message and get a streaming response
  Stream<String> sendMessageStream(
    String message,
    List<ChatMessage> history, {
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 2048,
  });

  /// Get available models for this provider
  Future<List<String>> getAvailableModels();

  /// Test the connection to this provider
  Future<bool> testConnection();

  /// Get the provider type
  AIProvider get provider;

  /// Get the provider display name
  String get providerName;

  /// Get the current model ID
  String get modelId;

  /// Set the model to use
  void setModel(String modelId);

  /// Set the API key
  void setApiKey(String apiKey);
}

/// Result class for AI responses
class AIResponse {
  final String content;
  final String? error;
  final int? tokensUsed;
  final Duration? responseTime;

  AIResponse({
    required this.content,
    this.error,
    this.tokensUsed,
    this.responseTime,
  });

  bool get isSuccess => error == null;
  bool get isError => error != null;
}
