// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:docan/models/ai_provider.dart';
import 'package:docan/services/chat_service.dart';
import 'package:docan/services/storage_service.dart';

class _MockPathProvider extends PathProviderPlatform {
  _MockPathProvider(this.supportPath);
  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory supportDir;

  setUpAll(() {
    supportDir = Directory.systemTemp.createTempSync('docan_chat_test');
    PathProviderPlatform.instance = _MockPathProvider(supportDir.path);
  });

  tearDownAll(() {
    supportDir.deleteSync(recursive: true);
  });

  test('stale saved model self-heals to a confirmed-available model', () async {
    // A retired model id saved for Gemini (as could happen when a vendor
    // retires a model). In the test env the live fetch is mocked to fail,
    // so the service falls back to the built-in list — which must NOT
    // contain the stale id.
    SharedPreferences.setMockInitialValues({
      'flutter.selected_provider': 'gemini',
      'flutter.selected_model_gemini': 'gemini-2.0-flash-retired',
    });

    final storage = await StorageService.getInstance();
    final chat = ChatService(storage);
    await chat.initialize();

    expect(chat.selectedProvider, AIProvider.gemini);
    expect(chat.selectedModel, 'gemini-2.0-flash-retired');

    // Fetching the (fallback) list triggers validation
    final models = await chat.getAvailableModels(AIProvider.gemini);

    expect(models, isNot(contains('gemini-2.0-flash-retired')));
    expect(chat.selectedModel, AIProvider.gemini.defaultModel);

    // The corrected model is persisted per provider
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('selected_model_gemini'),
      AIProvider.gemini.defaultModel,
    );
  });

  test('provider default model is trusted, not corrected', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.selected_provider': 'gemini',
      'flutter.selected_model_gemini': 'gemini-3.8-flash',
    });

    final storage = await StorageService.getInstance();
    final chat = ChatService(storage);
    await chat.initialize();

    final models = await chat.getAvailableModels(AIProvider.gemini);
    expect(chat.selectedModel, 'gemini-3.8-flash');
    expect(models, isNotEmpty);
  });
}
