import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/ai_provider.dart';
import '../models/playbook.dart';
import 'ai_service.dart';
import 'gemini_service.dart';
import 'openai_service.dart';
import 'claude_service.dart';
import 'ollama_service.dart';
import 'lmstudio_service.dart';
import 'storage_service.dart';
import 'playbook_service.dart';

/// Chat service for managing conversations and AI interactions
class ChatService extends ChangeNotifier {
  final StorageService _storage;
  PlaybookService? _playbookService;

  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  AIProvider _selectedProvider = AIProvider.gemini;
  String _selectedModel = '';
  bool _isLoading = false;
  String? _error;
  double _temperature = 0.7;
  int _maxTokens = 2048;
  String _systemPrompt = '';

  // AI Services
  final Map<AIProvider, AIService> _services = {};

  ChatService(this._storage) {
    _initServices();
  }

  /// Set the playbook service reference
  void setPlaybookService(PlaybookService service) {
    _playbookService = service;
  }

  void _initServices() {
    _services[AIProvider.gemini] = GeminiService();
    _services[AIProvider.openai] = OpenAIService();
    _services[AIProvider.claude] = ClaudeService();
    _services[AIProvider.ollama] = OllamaService();
    _services[AIProvider.lmstudio] = LMStudioService();
  }

  // Getters
  List<Conversation> get conversations => _conversations;
  Conversation? get currentConversation => _currentConversation;
  AIProvider get selectedProvider => _selectedProvider;
  String get selectedModel =>
      _selectedModel.isEmpty ? _selectedProvider.defaultModel : _selectedModel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get temperature => _temperature;
  int get maxTokens => _maxTokens;
  String get systemPrompt => _systemPrompt;

  AIService get currentService => _services[_selectedProvider]!;

  /// Get available models for a provider (fetches from API)
  Future<List<String>> getAvailableModels(AIProvider provider) async {
    return await _services[provider]!.getAvailableModels();
  }

  /// Get map of configured providers (has API key or Ollama/LM Studio URL)
  Future<Map<AIProvider, bool>> getConfiguredProviders() async {
    final result = <AIProvider, bool>{};
    for (final provider in AIProvider.values) {
      if (provider == AIProvider.ollama || provider == AIProvider.lmstudio) {
        // For Ollama and LM Studio, check if it's reachable
        final isConnected = await testConnection(provider);
        result[provider] = isConnected;
      } else {
        final hasKey = await _storage.hasApiKey(provider);
        result[provider] = hasKey;
      }
    }
    return result;
  }

  /// Initialize the chat service
  Future<void> initialize() async {
    // Load conversations
    _conversations = await _storage.loadConversations();

    // Load settings
    _selectedProvider = await _storage.getSelectedProvider();
    _selectedModel =
        await _storage.getSelectedModel() ?? _selectedProvider.defaultModel;
    _temperature = await _storage.getTemperature();
    _maxTokens = await _storage.getMaxTokens();
    _systemPrompt = await _storage.getSystemPrompt();

    // Load API keys
    for (final provider in AIProvider.values) {
      final apiKey = await _storage.getApiKey(provider);
      if (apiKey != null && apiKey.isNotEmpty) {
        _services[provider]?.setApiKey(apiKey);
      }
    }

    // Load LM Studio URL (stored separately from API keys)
    final lmStudioUrl = await _storage.getLMStudioUrl();
    (_services[AIProvider.lmstudio] as LMStudioService?)?.setBaseUrl(
      lmStudioUrl,
    );

    // Set models
    for (final service in _services.values) {
      service.setModel(_selectedModel);
    }

    notifyListeners();
  }

  /// Set the selected provider
  Future<void> setProvider(AIProvider provider) async {
    _selectedProvider = provider;
    _selectedModel = provider.defaultModel;
    await _storage.setSelectedProvider(provider);
    await _storage.setSelectedModel(_selectedModel);
    notifyListeners();
  }

  /// Set the selected model
  Future<void> setModel(String modelId) async {
    _selectedModel = modelId;
    currentService.setModel(modelId);
    await _storage.setSelectedModel(modelId);
    notifyListeners();
  }

  /// Set API key for a provider
  Future<void> setApiKey(AIProvider provider, String apiKey) async {
    await _storage.setApiKey(provider, apiKey);
    _services[provider]?.setApiKey(apiKey);
    notifyListeners();
  }

  /// Set temperature
  Future<void> setTemperature(double temp) async {
    _temperature = temp;
    await _storage.setTemperature(temp);
    notifyListeners();
  }

  /// Set max tokens
  Future<void> setMaxTokens(int tokens) async {
    _maxTokens = tokens;
    await _storage.setMaxTokens(tokens);
    notifyListeners();
  }

  /// Set system prompt
  Future<void> setSystemPrompt(String prompt) async {
    _systemPrompt = prompt;
    await _storage.setSystemPrompt(prompt);
    notifyListeners();
  }

  /// Create a new conversation
  Conversation createConversation({String? title}) {
    final conversation = Conversation.create(
      title: title,
      provider: _selectedProvider,
      modelId: selectedModel,
    );
    _conversations.insert(0, conversation);
    _currentConversation = conversation;
    _saveConversations();
    notifyListeners();
    return conversation;
  }

  /// Select a conversation
  void selectConversation(Conversation conversation) {
    _currentConversation = conversation;
    _selectedProvider = conversation.provider;
    _selectedModel = conversation.modelId;
    notifyListeners();
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    _conversations.removeWhere((c) => c.id == conversationId);
    if (_currentConversation?.id == conversationId) {
      _currentConversation = _conversations.isNotEmpty
          ? _conversations.first
          : null;
    }
    await _storage.deleteConversation(conversationId);
    notifyListeners();
  }

  /// Parse /playbook command from message
  /// Returns (playbookName, remainingMessage) or (null, originalMessage)
  (String?, String) _parsePlaybookCommand(String content) {
    final trimmed = content.trim();
    final playbookRegex = RegExp(
      r'^/playbook\s+(\S+)\s*(.*)',
      caseSensitive: false,
      dotAll: true,
    );
    final match = playbookRegex.firstMatch(trimmed);

    if (match != null) {
      final playbookName = match.group(1)!;
      final remainingMessage = match.group(2)?.trim() ?? '';
      return (playbookName, remainingMessage);
    }

    return (null, content);
  }

  /// Build system prompt with playbook context
  String _buildPlaybookSystemPrompt(Playbook playbook, String? basePrompt) {
    final buffer = StringBuffer();

    if (basePrompt != null && basePrompt.isNotEmpty) {
      buffer.writeln(basePrompt);
      buffer.writeln();
    }

    buffer.writeln(
      'You have access to the "${playbook.name}" playbook which can perform the following actions:',
    );
    buffer.writeln();

    for (final action in playbook.actions) {
      buffer.writeln('## ${action.name}');
      if (action.description != null) {
        buffer.writeln(action.description);
      }

      if (action.parameters.isNotEmpty) {
        buffer.writeln('Parameters:');
        for (final param in action.parameters) {
          final req = param.required ? '(required)' : '(optional)';
          buffer.writeln(
            '- ${param.name}: ${param.type} $req${param.description != null ? ' - ${param.description}' : ''}',
          );
        }
      }
      buffer.writeln();
    }

    buffer.writeln(
      'When the user asks you to do something that matches one of these actions, respond with:',
    );
    buffer.writeln('```playbook');
    buffer.writeln('action: <action_name>');
    buffer.writeln('parameters:');
    buffer.writeln('  param1: value1');
    buffer.writeln('  param2: value2');
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln(
      'Only use this format when you need to execute a playbook action. For regular conversation, respond normally.',
    );

    return buffer.toString();
  }

  /// Parse playbook action from AI response
  Map<String, dynamic>? _parsePlaybookAction(String response) {
    final regex = RegExp(r'```playbook\s*([\s\S]*?)\s*```');
    final match = regex.firstMatch(response);

    if (match == null) return null;

    try {
      final yamlContent = match.group(1)!;
      final lines = yamlContent.split('\n');
      String? actionName;
      final parameters = <String, dynamic>{};
      bool inParameters = false;

      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;

        if (trimmedLine.startsWith('action:')) {
          actionName = trimmedLine.substring(7).trim();
        } else if (trimmedLine == 'parameters:') {
          inParameters = true;
        } else if (inParameters && trimmedLine.contains(':')) {
          final colonIndex = trimmedLine.indexOf(':');
          final key = trimmedLine.substring(0, colonIndex).trim();
          var value = trimmedLine.substring(colonIndex + 1).trim();

          // Try to parse as number or boolean
          if (value == 'true') {
            parameters[key] = true;
          } else if (value == 'false') {
            parameters[key] = false;
          } else if (int.tryParse(value) != null) {
            parameters[key] = int.parse(value);
          } else if (double.tryParse(value) != null) {
            parameters[key] = double.parse(value);
          } else {
            // Remove surrounding quotes if present
            if ((value.startsWith('"') && value.endsWith('"')) ||
                (value.startsWith("'") && value.endsWith("'"))) {
              value = value.substring(1, value.length - 1);
            }
            parameters[key] = value;
          }
        }
      }

      if (actionName != null) {
        return {'action': actionName, 'parameters': parameters};
      }
    } catch (e) {
      debugPrint('[ChatService] Failed to parse playbook action: $e');
    }

    return null;
  }

  /// Send a message
  Future<void> sendMessage(
    String content, {
    List<Attachment>? attachments,
  }) async {
    debugPrint('[ChatService] sendMessage called');
    debugPrint(
      '[ChatService] Provider: ${_selectedProvider.name}, Model: $selectedModel',
    );
    debugPrint('[ChatService] Attachments: ${attachments?.length ?? 0}');

    if (content.trim().isEmpty &&
        (attachments == null || attachments.isEmpty)) {
      debugPrint('[ChatService] Empty message and no attachments, returning');
      return;
    }

    _error = null;

    // Check for /playbook command
    final (specifiedPlaybookName, messageContent) = _parsePlaybookCommand(
      content,
    );
    Playbook? activePlaybook;

    if (specifiedPlaybookName != null && _playbookService != null) {
      activePlaybook = _playbookService!.getPlaybookByName(
        specifiedPlaybookName,
      );
      if (activePlaybook == null) {
        // Playbook not found - let user know
        debugPrint('[ChatService] Playbook not found: $specifiedPlaybookName');
      } else if (!activePlaybook.enabled) {
        debugPrint(
          '[ChatService] Playbook is disabled: ${activePlaybook.name}',
        );
        activePlaybook = null;
      } else if (!activePlaybook.isConfigured) {
        debugPrint(
          '[ChatService] Playbook is not configured: ${activePlaybook.name}',
        );
        activePlaybook = null;
      } else {
        debugPrint('[ChatService] Using playbook: ${activePlaybook.name}');
      }
    }

    // If no explicit playbook, check for trigger matches
    if (activePlaybook == null && _playbookService != null) {
      final matches = _playbookService!.findMatchingPlaybooks(content);
      if (matches.isNotEmpty) {
        activePlaybook = matches.first.playbook;
        debugPrint(
          '[ChatService] Auto-matched playbook: ${activePlaybook.name} (confidence: ${matches.first.confidence})',
        );
      }
    }

    // Use the message content (with /playbook stripped if present)
    final effectiveContent = specifiedPlaybookName != null
        ? messageContent
        : content;

    // If specified playbook but empty message, show playbook info
    if (specifiedPlaybookName != null &&
        effectiveContent.isEmpty &&
        activePlaybook != null) {
      // Create conversation if needed
      if (_currentConversation == null) {
        createConversation();
      }

      final userMessage = ChatMessage.user('/playbook $specifiedPlaybookName');
      _currentConversation = _currentConversation!.addMessage(userMessage);

      // Generate playbook info response
      final infoBuffer = StringBuffer();
      infoBuffer.writeln(
        '**${activePlaybook.name}** v${activePlaybook.version}',
      );
      if (activePlaybook.description != null) {
        infoBuffer.writeln();
        infoBuffer.writeln(activePlaybook.description);
      }
      infoBuffer.writeln();
      infoBuffer.writeln('**Available Actions:**');
      for (final action in activePlaybook.actions) {
        infoBuffer.writeln(
          '- `${action.name}`: ${action.description ?? 'No description'}',
        );
      }
      infoBuffer.writeln();
      infoBuffer.writeln(
        'Usage: `/playbook ${activePlaybook.name.toLowerCase().replaceAll(' ', '_')} <your request>`',
      );

      final infoMessage = ChatMessage.assistant(
        infoBuffer.toString(),
        modelId: 'system',
      );
      _currentConversation = _currentConversation!.addMessage(infoMessage);
      _updateConversationInList();
      _saveConversations();
      notifyListeners();
      return;
    }

    // Create conversation if needed
    if (_currentConversation == null) {
      debugPrint('[ChatService] Creating new conversation');
      createConversation();
    }

    // Add user message with attachments
    final userMessage = ChatMessage.user(content, attachments: attachments);
    _currentConversation = _currentConversation!.addMessage(userMessage);
    _updateConversationInList();
    notifyListeners();

    // Create placeholder for AI response
    final placeholderMessage = ChatMessage.streaming(modelId: selectedModel);
    _currentConversation = _currentConversation!.addMessage(placeholderMessage);
    _updateConversationInList();
    _isLoading = true;
    notifyListeners();

    try {
      // Get history excluding the placeholder AND the current user message
      // (current message is passed separately to sendMessageStream)
      final allMessages = _currentConversation!.messages
          .where((m) => m.id != placeholderMessage.id && m.id != userMessage.id)
          .toList();
      final history = allMessages;

      // Build system prompt with playbook context if active
      String? effectiveSystemPrompt = _systemPrompt.isNotEmpty
          ? _systemPrompt
          : null;
      if (activePlaybook != null) {
        effectiveSystemPrompt = _buildPlaybookSystemPrompt(
          activePlaybook,
          effectiveSystemPrompt,
        );
      }

      debugPrint('[ChatService] Starting stream request');
      debugPrint('[ChatService] History messages: ${history.length}');
      debugPrint(
        '[ChatService] Temperature: $_temperature, MaxTokens: $_maxTokens',
      );
      debugPrint(
        '[ChatService] System prompt: ${effectiveSystemPrompt != null
            ? "set (with playbook)"
            : _systemPrompt.isNotEmpty
            ? "set"
            : "none"}',
      );

      String fullResponse = '';
      bool success = false;
      String? lastError;

      // Try current model first, then fallback models on 429
      final modelsToTry = [
        _selectedModel,
        ..._getFallbackModels(_selectedProvider, _selectedModel),
      ];

      for (final modelToTry in modelsToTry) {
        try {
          debugPrint('[ChatService] Trying model: $modelToTry');
          currentService.setModel(modelToTry);

          // Use streaming
          final stream = currentService.sendMessageStream(
            effectiveContent.isNotEmpty ? effectiveContent : content,
            history,
            systemPrompt: effectiveSystemPrompt,
            temperature: _temperature,
            maxTokens: _maxTokens,
            attachments: attachments,
          );

          fullResponse = '';
          await for (final chunk in stream) {
            fullResponse += chunk;
            final updatedMessage = placeholderMessage.copyWith(
              content: fullResponse,
              isStreaming: true,
              modelId: modelToTry,
            );
            _currentConversation = _currentConversation!.updateMessage(
              placeholderMessage.id,
              updatedMessage,
            );
            _updateConversationInList();
            notifyListeners();
          }

          success = true;
          // Update selected model if we had to fallback
          if (modelToTry != _selectedModel) {
            debugPrint(
              '[ChatService] Successfully fell back to model: $modelToTry',
            );
            _selectedModel = modelToTry;
          }
          break; // Success, exit loop
        } catch (e) {
          lastError = e.toString();
          debugPrint('[ChatService] Model $modelToTry failed: $e');

          // Check if it's a rate limit error (429)
          if (_isRateLimitError(e)) {
            debugPrint('[ChatService] Rate limit hit, trying next model...');
            continue; // Try next model
          } else {
            // For other errors, don't retry with different models
            rethrow;
          }
        }
      }

      if (!success) {
        throw Exception(
          lastError ??
              'All models failed due to rate limiting. Please try again later.',
        );
      }

      // Check if AI response contains a playbook action to execute
      String finalResponseContent = fullResponse;
      if (activePlaybook != null && _playbookService != null) {
        final actionData = _parsePlaybookAction(fullResponse);
        if (actionData != null) {
          debugPrint(
            '[ChatService] Executing playbook action: ${actionData['action']}',
          );

          // Execute the playbook action
          final result = await _playbookService!.executeAction(
            activePlaybook,
            actionData['action'] as String,
            actionData['parameters'] as Map<String, dynamic>,
          );

          if (result.success) {
            // Add playbook result to response
            final resultJson = result.data != null
                ? const JsonEncoder.withIndent('  ').convert(result.data)
                : 'Action completed successfully';

            // Remove the playbook code block and add the result
            final cleanedResponse = fullResponse
                .replaceAll(RegExp(r'```playbook\s*[\s\S]*?\s*```'), '')
                .trim();

            finalResponseContent = cleanedResponse.isNotEmpty
                ? '$cleanedResponse\n\n**Result:**\n```json\n$resultJson\n```'
                : '**Result:**\n```json\n$resultJson\n```';
          } else {
            // Show error
            final cleanedResponse = fullResponse
                .replaceAll(RegExp(r'```playbook\s*[\s\S]*?\s*```'), '')
                .trim();

            finalResponseContent = cleanedResponse.isNotEmpty
                ? '$cleanedResponse\n\n**Error:** ${result.error}'
                : '**Error:** ${result.error}';
          }
        }
      }

      // Finalize message
      final finalMessage = placeholderMessage.copyWith(
        content: finalResponseContent,
        isStreaming: false,
      );
      _currentConversation = _currentConversation!.updateMessage(
        placeholderMessage.id,
        finalMessage,
      );

      // Update conversation title if it's the first exchange
      if (_currentConversation!.messages.length <= 3) {
        _currentConversation = _currentConversation!.copyWith(
          title: _generateTitle(content),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[ChatService] ERROR: $e');
      debugPrint('[ChatService] Stack trace: $stackTrace');
      final errorMessage = placeholderMessage.copyWith(
        content: '',
        isStreaming: false,
        error: e.toString(),
      );
      _currentConversation = _currentConversation!.updateMessage(
        placeholderMessage.id,
        errorMessage,
      );
      _error = e.toString();
    }

    _isLoading = false;
    _updateConversationInList();
    _saveConversations();
    notifyListeners();
  }

  /// Generate a title from the first message
  String _generateTitle(String firstMessage) {
    final words = firstMessage.split(' ').take(5).join(' ');
    return words.length > 30 ? '${words.substring(0, 30)}...' : words;
  }

  /// Check if error is a rate limit (429) error
  bool _isRateLimitError(Object error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('429') ||
        errorStr.contains('rate limit') ||
        errorStr.contains('too many requests') ||
        errorStr.contains('quota exceeded') ||
        errorStr.contains('resource exhausted');
  }

  /// Get fallback models for a provider when rate limited
  List<String> _getFallbackModels(AIProvider provider, String currentModel) {
    final allModels = provider.availableModels;
    // Return all models except the current one, prioritizing similar tier models
    return allModels.where((m) => m != currentModel).toList();
  }

  /// Update conversation in list
  void _updateConversationInList() {
    if (_currentConversation == null) return;
    final index = _conversations.indexWhere(
      (c) => c.id == _currentConversation!.id,
    );
    if (index >= 0) {
      _conversations[index] = _currentConversation!;
    }
  }

  /// Save conversations to storage
  Future<void> _saveConversations() async {
    await _storage.saveConversations(_conversations);
  }

  /// Test connection for a provider
  Future<bool> testConnection(AIProvider provider) async {
    return await _services[provider]?.testConnection() ?? false;
  }

  /// Check if API key is set for a provider
  Future<bool> hasApiKey(AIProvider provider) async {
    return await _storage.hasApiKey(provider);
  }

  /// Clear all conversations
  Future<void> clearAllConversations() async {
    _conversations.clear();
    _currentConversation = null;
    await _storage.clearAllConversations();
    notifyListeners();
  }

  /// Regenerate last response
  Future<void> regenerateLastResponse() async {
    if (_currentConversation == null) return;
    if (_currentConversation!.messages.length < 2) return;

    // Remove last AI message
    final messages = _currentConversation!.messages;
    if (messages.last.role == MessageRole.assistant) {
      _currentConversation = _currentConversation!.removeMessage(
        messages.last.id,
      );

      // Get the last user message and resend
      final lastUserMessage = _currentConversation!.messages.last;
      if (lastUserMessage.role == MessageRole.user) {
        _currentConversation = _currentConversation!.removeMessage(
          lastUserMessage.id,
        );
        await sendMessage(lastUserMessage.content);
      }
    }
  }

  /// Get pinned conversations
  List<Conversation> get pinnedConversations =>
      _conversations.where((c) => c.isPinned && !c.isArchived).toList();

  /// Get active conversations (not archived)
  List<Conversation> get activeConversations =>
      _conversations.where((c) => !c.isArchived).toList();

  /// Get archived conversations
  List<Conversation> get archivedConversations =>
      _conversations.where((c) => c.isArchived).toList();

  /// Toggle pin status
  Future<void> togglePin(String conversationId) async {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      _conversations[index] = _conversations[index].copyWith(
        isPinned: !_conversations[index].isPinned,
      );
      await _saveConversations();
      notifyListeners();
    }
  }

  /// Toggle archive status
  Future<void> toggleArchive(String conversationId) async {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      _conversations[index] = _conversations[index].copyWith(
        isArchived: !_conversations[index].isArchived,
      );
      await _saveConversations();
      notifyListeners();
    }
  }
}
