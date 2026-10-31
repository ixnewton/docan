import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';
import 'package:docan/models/chat_message.dart';
import 'package:docan/models/usage_stats.dart';
import 'package:docan/services/ai_service.dart';
import 'package:docan/utils/yaml_emitter.dart';
import 'package:docan/utils/playbook_generator.dart';

class _FakeAIService implements AIService {
  final String response;
  _FakeAIService(this.response);

  @override
  TokenUsage? lastUsage;

  @override
  Future<String> sendMessage(
    String message,
    List<ChatMessage> history, {
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 2048,
    List<Attachment>? attachments,
  }) async {
    lastPrompt = message;
    return response;
  }

  String? lastPrompt;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const samplePlaybook = {
  'name': 'Weather',
  'version': '1.0.0',
  'playbookVersion': 1,
  'description': 'Weather lookups',
  'config': {
    'apiKey': {
      'type': 'string',
      'required': true,
      'secret': true,
      'description': "API key for the service (has: colons, 'quotes')",
    },
  },
  'triggers': [
    {'pattern': 'weather|rain', 'description': 'Weather queries', 'priority': 5},
  ],
  'actions': {
    'getWeather': {
      'description': 'Get the forecast',
      'parameters': {
        'location': {'type': 'string', 'required': true},
        'days': {'type': 'number', 'default': 3},
      },
      'steps': [
        {
          'type': 'http',
          'method': 'GET',
          'url': 'https://api.example.com/search?q={{params.location}}',
          'params': {'q': '{{params.location}}'},
          'response': {'store': 'searchResults'},
          'onFailure': 'continue',
        },
        {'type': 'returnData', 'data': {'results': '{{searchResults}}'}},
      ],
      'returns': {'type': 'object'},
    },
  },
};

void main() {
  group('emitYaml', () {
    test('round-trips a playbook-like structure through loadYaml', () {
      final emitted = emitYaml(samplePlaybook);
      final loaded = loadYaml(emitted);

      expect(loaded['name'], 'Weather');
      expect(loaded['config']['apiKey']['secret'], true);
      expect(
        loaded['config']['apiKey']['description'],
        "API key for the service (has: colons, 'quotes')",
      );
      final steps = loaded['actions']['getWeather']['steps'] as YamlList;
      expect(steps.length, 2);
      expect(steps[0]['type'], 'http');
      expect(steps[0]['params']['q'], '{{params.location}}');
      expect(steps[0]['onFailure'], 'continue');
      expect(steps[1]['type'], 'returnData');
    });

    test('emits step YAML that re-parses to the same step', () {
      final actions = samplePlaybook['actions'] as Map<String, dynamic>;
      final getWeather = actions['getWeather'] as Map<String, dynamic>;
      final steps = getWeather['steps'] as List;
      final step = steps[0] as Map<String, dynamic>;
      final emitted = emitYaml(step);
      final loaded = loadYaml(emitted) as YamlMap;
      expect(loaded['type'], 'http');
      expect(loaded['response']['store'], 'searchResults');
    });

    test('quotes scalar-looking strings, numbers and booleans', () {
      final emitted = emitYaml({
        'a': 'true',
        'b': '123',
        'c': 'plain',
        'd': 'has: colon',
        'e': true,
        'f': 42,
      });
      final loaded = loadYaml(emitted);
      expect(loaded['a'], 'true');
      expect(loaded['b'], '123');
      expect(loaded['c'], 'plain');
      expect(loaded['d'], 'has: colon');
      expect(loaded['e'], true);
      expect(loaded['f'], 42);
    });
  });

  group('PlaybookGenerator', () {
    test('extracts the yaml block from the model response', () async {
      final service = _FakeAIService(
        'Here is your playbook:\n'
        '```yaml\nname: Weather\nversion: 1.0.0\nplaybookVersion: 1\n```\n'
        'Enjoy!',
      );
      final yaml = await PlaybookGenerator.generateYaml(
        service,
        'weather lookups',
      );
      expect(yaml, contains('name: Weather'));
      expect(yaml, isNot(contains('```')));
    });

    test('accepts a bare response that is already playbook YAML', () async {
      final service = _FakeAIService('name: Weather\nversion: 1.0.0\n');
      final yaml = await PlaybookGenerator.generateYaml(service, 'anything');
      expect(yaml, contains('name: Weather'));
    });

    test('throws a readable error when no usable YAML is returned', () async {
      final service = _FakeAIService('Sorry, I cannot do that.');
      expect(
        () => PlaybookGenerator.generateYaml(service, 'x'),
        throwsFormatException,
      );
    });

    test('prompt includes the essential schema requirements', () async {
      final service = _FakeAIService('name: X\n');
      await PlaybookGenerator.generateYaml(service, 'my service');
      final prompt = service.lastPrompt!;
      expect(prompt, contains('playbookVersion: 1'));
      expect(prompt, contains('my service'));
      expect(prompt, contains('Do NOT use askUser or askAI'));
      expect(prompt, contains('returnData'));
    });
  });
}
