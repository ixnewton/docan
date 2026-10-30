import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docan/models/ai_provider.dart';
import 'package:docan/models/conversation.dart';
import 'package:docan/services/chat_service.dart';
import 'package:docan/services/storage_service.dart';

void main() {
  late StorageService storage;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    storage = await StorageService.getInstance();
  });

  test('keeps the saved provider when it is currently available', () async {
    await storage.setSelectedProvider(AIProvider.gemini);
    await storage.setProviderRecency([AIProvider.gemini]);
    await storage.setApiKey(AIProvider.gemini, 'test-key');

    final chat = ChatService(storage);
    await chat.initialize();
    await chat.prefetchModelLists();

    expect(chat.selectedProvider, AIProvider.gemini);
  });

  test('switches to the most recent available provider when saved is unavailable',
      () async {
    await storage.setSelectedProvider(AIProvider.ollama);
    await storage.setProviderRecency([AIProvider.ollama, AIProvider.gemini]);

    final chat = ChatService(storage);
    await chat.initialize();
    await chat.prefetchModelLists();

    expect(chat.selectedProvider, AIProvider.gemini);
    expect(
      await storage.getSelectedProvider(),
      AIProvider.ollama,
      reason: 'the startup fallback must not overwrite the saved preference',
    );
  });

  test('falls back to the first available provider when recency has none',
      () async {
    await storage.setSelectedProvider(AIProvider.ollama);
    await storage.setProviderRecency([]);

    final chat = ChatService(storage);
    await chat.initialize();
    await chat.prefetchModelLists();

    expect(chat.selectedProvider, AIProvider.gemini);
  });

  test('selecting a conversation applies its provider and model', () async {
    await storage.setApiKey(AIProvider.claude, 'test-key');

    final chat = ChatService(storage);
    await chat.initialize();

    final conv = Conversation.create(
      title: 'claude chat',
      provider: AIProvider.claude,
      modelId: 'claude-sonnet-5-5',
    );
    await chat.selectConversation(conv);

    expect(chat.selectedProvider, AIProvider.claude);
    expect(chat.selectedModel, 'claude-sonnet-5-5');
  });

  test(
      'selecting a conversation with an unconfigured provider keeps the '
      'current combination', () async {
    final chat = ChatService(storage);
    await chat.initialize();
    final providerBefore = chat.selectedProvider;
    final modelBefore = chat.selectedModel;

    final conv = Conversation.create(
      title: 'deepseek chat',
      provider: AIProvider.deepseek,
      modelId: 'deepseek-chat-model',
    );
    await chat.selectConversation(conv);

    expect(chat.selectedProvider, providerBefore);
    expect(chat.selectedModel, modelBefore);
  });
}
