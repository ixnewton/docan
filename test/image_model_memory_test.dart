import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:docan/services/image_generation_service.dart';
import 'package:docan/services/storage_service.dart';

void main() {
  test('image provider and model selection persist across sessions', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.getInstance();

    final service = ImageGenerationService(storage);
    await service.initialize();
    expect(service.selectedProvider, ImageGenProvider.gemini);
    expect(service.selectedModel, ImageGenProvider.gemini.defaultModel);

    await service.setProvider(ImageGenProvider.openai);
    await service.setModel('gpt-image-1');

    final nextSession = ImageGenerationService(storage);
    await nextSession.initialize();
    expect(nextSession.selectedProvider, ImageGenProvider.openai);
    expect(nextSession.selectedModel, 'gpt-image-1');

    await nextSession.setProvider(ImageGenProvider.gemini);
    expect(
      nextSession.selectedModel,
      ImageGenProvider.gemini.defaultModel,
      reason: 'switching providers restores that provider last-used model',
    );
  });

  test('filterImageModels keeps only image-capable OpenRouter models', () {
    final models = ImageGenerationService.filterImageModels([
      {
        'id': 'google/gemini-2.5-flash-image',
        'architecture': {'output_modalities': ['image', 'text']},
      },
      {
        'id': 'openai/gpt-4o',
        'architecture': {'output_modalities': ['text']},
      },
      {'id': 'no-architecture-model'},
    ]);
    expect(models, ['google/gemini-2.5-flash-image']);
  });

  test('extractImageData pulls the base64 image from a data URL', () {
    final image = ImageGenerationService.extractImageData(
      'Here you go:\n![generated](data:image/png;base64,QUJDREVG)',
    );
    expect(image, isNotNull);
    expect(image!.$1, 'png');
    expect(image.$2, 'QUJDREVG');
  });

  test('extractImageData returns null without an image', () {
    expect(ImageGenerationService.extractImageData('just text'), isNull);
  });

  test('extractOpenRouterImage reads the /images b64_json shape', () {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    final b64 = base64Encode(png);
    final (mime, data) = ImageGenerationService.extractOpenRouterImage({
      'data': [
        {'b64_json': b64},
      ],
      'usage': {'cost': 0.04},
    });
    expect(mime, 'image/png');
    expect(data, b64);
  });

  test('extractOpenRouterImage reads message.images (chat completions)', () {
    final (mime, data) =
        ImageGenerationService.extractOpenRouterImage({
      'choices': [
        {
          'message': {
            'role': 'assistant',
            'content': 'Here is the generated image.',
            'images': [
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/png;base64,QUJDREVG',
                },
              },
            ],
          },
        },
      ],
    });
    expect(mime, 'image/png');
    expect(data, 'QUJDREVG');
  });

  test('extractOpenRouterImage reads content as a list of parts', () {
    final (mime, data) =
        ImageGenerationService.extractOpenRouterImage({
      'choices': [
        {
          'message': {
            'content': [
              {'type': 'text', 'text': 'Here is the image.'},
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,Sk9C'},
              },
            ],
          },
        },
      ],
    });
    expect(mime, 'image/jpeg');
    expect(data, 'Sk9C');
  });

  test('extractOpenRouterImage reads a markdown data URL in content', () {
    final (mime, data) =
        ImageGenerationService.extractOpenRouterImage({
      'choices': [
        {
          'message': {
            'content': '![img](data:image/webp;base64,V0VCUA==)',
          },
        },
      ],
    });
    expect(mime, 'image/webp');
    expect(data, 'V0VCUA==');
  });

  test('extractOpenRouterImage returns null base64 when nothing matches', () {
    final (_, data) = ImageGenerationService.extractOpenRouterImage({
      'choices': [
        {
          'message': {'content': 'no image here'},
        },
      ],
    });
    expect(data, isNull);
  });

  test('detectImageMime identifies png, jpeg and gif magic bytes', () {
    expect(
      ImageGenerationService.detectImageMime(
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0]),
      ),
      'image/png',
    );
    expect(
      ImageGenerationService.detectImageMime(
        Uint8List.fromList([0xFF, 0xD8, 0xFF]),
      ),
      'image/jpeg',
    );
    expect(
      ImageGenerationService.detectImageMime(
        Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]),
      ),
      'image/gif',
    );
    expect(
      ImageGenerationService.detectImageMime(Uint8List.fromList([1, 2, 3])),
      'image/png',
    );
  });
}
