import 'package:flutter/material.dart';

/// Supported AI Providers
enum AIProvider { gemini, openai, claude, ollama, lmstudio }

/// Extension methods for AIProvider
extension AIProviderExtension on AIProvider {
  String get displayName {
    switch (this) {
      case AIProvider.gemini:
        return 'Gemini';
      case AIProvider.openai:
        return 'ChatGPT';
      case AIProvider.claude:
        return 'Claude';
      case AIProvider.ollama:
        return 'Ollama';
      case AIProvider.lmstudio:
        return 'LM Studio';
    }
  }

  String get description {
    switch (this) {
      case AIProvider.gemini:
        return 'Google\'s Gemini AI';
      case AIProvider.openai:
        return 'OpenAI ChatGPT';
      case AIProvider.claude:
        return 'Anthropic Claude';
      case AIProvider.ollama:
        return 'Local AI Models';
      case AIProvider.lmstudio:
        return 'Local AI via LM Studio';
    }
  }

  IconData get icon {
    switch (this) {
      case AIProvider.gemini:
        return Icons.auto_awesome;
      case AIProvider.openai:
        return Icons.psychology;
      case AIProvider.claude:
        return Icons.smart_toy;
      case AIProvider.ollama:
        return Icons.computer;
      case AIProvider.lmstudio:
        return Icons.desktop_windows;
    }
  }

  Color get color {
    switch (this) {
      case AIProvider.gemini:
        return const Color(0xFF4285F4); // Google Blue
      case AIProvider.openai:
        return const Color(0xFF10A37F); // OpenAI Green
      case AIProvider.claude:
        return const Color(0xFFCC785C); // Anthropic Orange
      case AIProvider.ollama:
        return const Color(0xFF6B7280); // Neutral Gray
      case AIProvider.lmstudio:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  List<String> get availableModels {
    switch (this) {
      case AIProvider.gemini:
        return [
          'gemini-3-pro-preview',
          'gemini-3-pro-image-preview',
          'gemini-2.5-pro',
          'gemini-2.5-flash',
          'gemini-2.5-flash-image',
          'gemini-2.5-flash-lite',
        ];
      case AIProvider.openai:
        return ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'];
      case AIProvider.claude:
        return [
          'claude-sonnet-4-20250514',
          'claude-3-5-sonnet-20241022',
          'claude-3-5-haiku-20241022',
        ];
      case AIProvider.ollama:
        return [
          'llama3.2',
          'llama3.1',
          'mistral',
          'codestral',
          'phi4',
          'deepseek-r1',
          'qwen2.5',
          'gemma2',
        ];
      case AIProvider.lmstudio:
        return ['Select a model from LM Studio'];
    }
  }

  String get defaultModel {
    switch (this) {
      case AIProvider.gemini:
        return 'gemini-2.5-flash';
      case AIProvider.openai:
        return 'gpt-4o';
      case AIProvider.claude:
        return 'claude-sonnet-4-20250514';
      case AIProvider.ollama:
        return 'llama3.2';
      case AIProvider.lmstudio:
        return 'default';
    }
  }

  String get apiKeyName {
    switch (this) {
      case AIProvider.gemini:
        return 'Gemini API Key';
      case AIProvider.openai:
        return 'OpenAI API Key';
      case AIProvider.claude:
        return 'Claude API Key';
      case AIProvider.ollama:
        return 'Ollama URL';
      case AIProvider.lmstudio:
        return 'LM Studio URL';
    }
  }

  bool get requiresApiKey {
    return this != AIProvider.ollama && this != AIProvider.lmstudio;
  }
}

/// Model configuration for API calls
class ModelConfig {
  final AIProvider provider;
  final String modelId;
  final double temperature;
  final int maxTokens;
  final String? systemPrompt;

  const ModelConfig({
    required this.provider,
    required this.modelId,
    this.temperature = 0.7,
    this.maxTokens = 2048,
    this.systemPrompt,
  });

  ModelConfig copyWith({
    AIProvider? provider,
    String? modelId,
    double? temperature,
    int? maxTokens,
    String? systemPrompt,
  }) {
    return ModelConfig(
      provider: provider ?? this.provider,
      modelId: modelId ?? this.modelId,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider.name,
      'modelId': modelId,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'systemPrompt': systemPrompt,
    };
  }

  factory ModelConfig.fromJson(Map<String, dynamic> json) {
    return ModelConfig(
      provider: AIProvider.values.firstWhere(
        (e) => e.name == json['provider'],
        orElse: () => AIProvider.gemini,
      ),
      modelId: json['modelId'] ?? 'gemini-2.5-flash',
      temperature: (json['temperature'] ?? 0.7).toDouble(),
      maxTokens: json['maxTokens'] ?? 2048,
      systemPrompt: json['systemPrompt'],
    );
  }
}
