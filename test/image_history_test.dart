import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docan/services/image_generation_service.dart';
import 'package:docan/services/storage_service.dart';

void main() {
  group('SavedImageRecord serialization', () {
    test('round-trips through JSON', () {
      final record = SavedImageRecord(
        fileName: 'docan_image_123.png',
        prompt: 'a red panda astronaut',
        provider: 'openrouter',
        model: 'google/gemini-nano-banana-2.1',
        savedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      final restored = SavedImageRecord.listFromJson(
        SavedImageRecord.listToJson([record]),
      );
      expect(restored.length, 1);
      expect(restored.first.fileName, 'docan_image_123.png');
      expect(restored.first.prompt, 'a red panda astronaut');
      expect(restored.first.provider, 'openrouter');
      expect(restored.first.model, 'google/gemini-nano-banana-2.1');
      expect(
        restored.first.savedAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
    });

    test('empty and invalid input yield an empty list', () {
      expect(SavedImageRecord.listFromJson(''), isEmpty);
      expect(SavedImageRecord.listFromJson('not json'), isEmpty);
    });
  });

  group('ImageGenerationService history', () {
    late Directory tempDir;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      tempDir = Directory.systemTemp.createTempSync('docan_hist');
    });
    tearDown(() => tempDir.deleteSync(recursive: true));

    Future<ImageGenerationService> makeService() async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.getInstance();
      final service = ImageGenerationService(storage);
      await service.initialize();
      await service.setSaveFolderOverride(tempDir.path);
      return service;
    }

    GeneratedImage makeImage(String prompt) => GeneratedImage(
      prompt: prompt,
      imageData: Uint8List.fromList([1, 2, 3, 4]),
      provider: ImageGenProvider.openrouter,
      model: 'test-model',
    );

    test('saveImageToHistory writes the file and records the prompt', () async {
      final service = await makeService();
      final path = await service.saveImageToHistory(
        makeImage('a red panda astronaut'),
      );

      expect(File(path).existsSync(), isTrue);
      expect(service.imageHistory.length, 1);
      expect(service.imageHistory.first.prompt, 'a red panda astronaut');
      expect(service.imageHistory.first.provider, 'openrouter');
      expect(service.imageHistory.first.model, 'test-model');
    });

    test('history persists across sessions in creation order', () async {
      final service = await makeService();
      await service.saveImageToHistory(makeImage('first prompt'));
      await Future.delayed(const Duration(milliseconds: 5));
      await service.saveImageToHistory(makeImage('second prompt'));

      final nextSession = ImageGenerationService(
        (await StorageService.getInstance()),
      );
      await nextSession.initialize();
      await nextSession.setSaveFolderOverride(tempDir.path);

      final prompts = nextSession.imageHistory.map((r) => r.prompt).toList();
      expect(prompts.contains('first prompt'), isTrue);
      expect(prompts.contains('second prompt'), isTrue);
      expect(
        prompts.indexOf('first prompt'),
        lessThan(prompts.indexOf('second prompt')),
        reason: 'records keep creation order',
      );
    });

    test('historyByDay groups by day, newest first, dropping missing files',
        () async {
      final service = await makeService();
      await service.saveImageToHistory(makeImage('today image'));
      await service.saveImageToHistory(makeImage('missing later'));

      // Simulate a previous-day record whose file exists, and drop one
      // whose file was deleted from the folder
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      File(
        '${tempDir.path}/docan_image_yesterday.png',
      ).writeAsBytesSync([9, 9, 9]);
      final records = List.of(service.imageHistory)
        ..add(
          SavedImageRecord(
            fileName: 'docan_image_yesterday.png',
            prompt: 'yesterday image',
            provider: 'openrouter',
            model: 'test-model',
            savedAt: yesterday,
          ),
        )
        ..add(
          SavedImageRecord(
            fileName: 'docan_image_deleted.png',
            prompt: 'deleted image',
            provider: 'openrouter',
            model: 'test-model',
            savedAt: yesterday,
          ),
        );
      await (await StorageService.getInstance()).setImageHistory(
        SavedImageRecord.listToJson(records),
      );
      final reloaded = ImageGenerationService(
        await StorageService.getInstance(),
      );
      await reloaded.initialize();
      await reloaded.setSaveFolderOverride(tempDir.path);

      final byDay = await reloaded.historyByDay();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterdayDay = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
      );
      // Newest day first
      expect(byDay.keys.first, today);
      expect(
        byDay[today]!.map((r) => r.prompt),
        containsAll(['today image', 'missing later']),
      );
      // The record whose file is missing from the folder is not shown
      expect(
        byDay[yesterdayDay]!.map((r) => r.prompt),
        ['yesterday image'],
      );
    });
  });
}
