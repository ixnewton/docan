import 'package:flutter/material.dart';
import 'ai_provider.dart';

/// Pre-built agent presets
class AgentPreset {
  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final AIProvider provider;
  final String modelId;
  final double temperature;
  final IconData icon;
  final Color accentColor;

  const AgentPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    required this.provider,
    required this.modelId,
    this.temperature = 0.7,
    required this.icon,
    required this.accentColor,
  });

  /// Default presets
  static const List<AgentPreset> defaults = [
    AgentPreset(
      id: 'code-assistant',
      name: 'Code Assistant',
      description: 'Expert programmer for code review and development',
      systemPrompt: '''You are an expert software developer and code reviewer. 
Help users write clean, efficient, and well-documented code. 
Provide explanations for your suggestions and follow best practices.
When reviewing code, be thorough but constructive.''',
      provider: AIProvider.claude,
      modelId: 'claude-sonnet-4-20250514',
      temperature: 0.3,
      icon: Icons.code,
      accentColor: Color(0xFF5856D6),
    ),
    AgentPreset(
      id: 'creative-writer',
      name: 'Creative Writer',
      description: 'Imaginative storyteller and content creator',
      systemPrompt: '''You are a creative writing assistant with a flair for 
storytelling, poetry, and engaging content. Help users craft compelling 
narratives, develop characters, and express ideas creatively. 
Be imaginative and inspire creativity.''',
      provider: AIProvider.openai,
      modelId: 'gpt-4o',
      temperature: 0.9,
      icon: Icons.edit_note,
      accentColor: Color(0xFFFF9500),
    ),
    AgentPreset(
      id: 'research-analyst',
      name: 'Research Analyst',
      description: 'Analytical researcher for in-depth analysis',
      systemPrompt: '''You are a thorough research analyst. Help users 
analyze information, synthesize data, and draw evidence-based conclusions. 
Provide well-structured analysis with clear reasoning and cite sources when possible.
Be objective and consider multiple perspectives.''',
      provider: AIProvider.gemini,
      modelId: 'gemini-1.5-pro',
      temperature: 0.5,
      icon: Icons.science,
      accentColor: Color(0xFF34C759),
    ),
    AgentPreset(
      id: 'general-chat',
      name: 'General Chat',
      description: 'Friendly conversational assistant',
      systemPrompt: '''You are a friendly and helpful AI assistant. 
Engage in natural conversation, answer questions clearly, and provide 
useful information. Be conversational yet informative.''',
      provider: AIProvider.openai,
      modelId: 'gpt-4o-mini',
      temperature: 0.7,
      icon: Icons.chat_bubble_outline,
      accentColor: Color(0xFF007AFF),
    ),
    AgentPreset(
      id: 'local-model',
      name: 'Local Model',
      description: 'Privacy-focused local AI processing',
      systemPrompt: '''You are a helpful AI assistant running locally. 
Provide clear and concise responses while being helpful and informative.''',
      provider: AIProvider.ollama,
      modelId: 'llama3.2',
      temperature: 0.7,
      icon: Icons.home,
      accentColor: Color(0xFF6B7280),
    ),
  ];

  /// Copy with modifications
  AgentPreset copyWith({
    String? id,
    String? name,
    String? description,
    String? systemPrompt,
    AIProvider? provider,
    String? modelId,
    double? temperature,
    IconData? icon,
    Color? accentColor,
  }) {
    return AgentPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      provider: provider ?? this.provider,
      modelId: modelId ?? this.modelId,
      temperature: temperature ?? this.temperature,
      icon: icon ?? this.icon,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'systemPrompt': systemPrompt,
      'provider': provider.name,
      'modelId': modelId,
      'temperature': temperature,
      'iconCodePoint': icon.codePoint,
      'accentColorValue': accentColor.value,
    };
  }

  /// Create from JSON
  factory AgentPreset.fromJson(Map<String, dynamic> json) {
    return AgentPreset(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      systemPrompt: json['systemPrompt'] ?? '',
      provider: AIProvider.values.firstWhere(
        (e) => e.name == json['provider'],
        orElse: () => AIProvider.gemini,
      ),
      modelId: json['modelId'] ?? 'gemini-2.0-flash-exp',
      temperature: (json['temperature'] ?? 0.7).toDouble(),
      icon: IconData(
        json['iconCodePoint'] ?? Icons.chat.codePoint,
        fontFamily: 'MaterialIcons',
      ),
      accentColor: Color(json['accentColorValue'] ?? 0xFF007AFF),
    );
  }
}
