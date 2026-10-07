import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:docan/models/conversation.dart';
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
  late File conversationsFile;

  setUpAll(() {
    supportDir = Directory.systemTemp.createTempSync('docan_storage_test');
    conversationsFile = File('${supportDir.path}/conversations.json');
    PathProviderPlatform.instance = _MockPathProvider(supportDir.path);
  });

  tearDownAll(() {
    supportDir.deleteSync(recursive: true);
  });

  test('migrates legacy prefs conversations to file and removes the key', () async {
    final legacy = jsonEncode([
      Conversation(id: 'c1', title: 'Test chat').toJson(),
    ]);
    SharedPreferences.setMockInitialValues({
      'flutter.conversations': legacy,
      'flutter.selected_provider': 'gemini',
    });

    final storage = await StorageService.getInstance();
    final loaded = await storage.loadConversations();

    expect(loaded, hasLength(1));
    expect(loaded.first.id, 'c1');
    expect(loaded.first.title, 'Test chat');
    expect(conversationsFile.existsSync(), isTrue);
    expect(conversationsFile.readAsStringSync(), legacy);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('conversations'), isNull);
  });

  test('saveConversations writes the file, not prefs', () async {
    final storage = await StorageService.getInstance();
    await storage.saveConversations([
      Conversation(id: 'c2', title: 'Second'),
      Conversation(id: 'c3', title: 'Third'),
    ]);

    expect(conversationsFile.existsSync(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('conversations'), isNull);

    final loaded = await storage.loadConversations();
    expect(loaded.map((c) => c.id), ['c2', 'c3']);
  });

  test('clearAllConversations deletes the file', () async {
    final storage = await StorageService.getInstance();
    await storage.clearAllConversations();

    expect(conversationsFile.existsSync(), isFalse);
    expect(await storage.loadConversations(), isEmpty);
  });
}
