// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:docan/services/openrouter_service.dart';

/// Live integration test against the OpenRouter API.
///
/// Skipped unless an OpenRouter key is available in the local Devin MCP
/// config (~/.config/devin/mcp_config.json) or the OPENROUTER_API_KEY
/// environment variable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? resolveKey() {
    final env = Platform.environment['OPENROUTER_API_KEY'];
    if (env != null && env.isNotEmpty && !env.startsWith('REPLACE')) {
      return env;
    }
    final file = File(
      '${Platform.environment['HOME']}/.config/devin/mcp_config.json',
    );
    if (!file.existsSync()) return null;
    try {
      final cfg = jsonDecode(file.readAsStringSync());
      final key = cfg['mcpServers']?['openrouter']?['env']
          ?['OPENROUTER_API_KEY'] as String?;
      if (key == null || key.isEmpty || key.startsWith('REPLACE')) return null;
      return key;
    } catch (_) {
      return null;
    }
  }

  test('OpenRouter live: models list and vendor grouping', () async {
    final key = resolveKey();
    if (key == null) {
      print('Skipping: no OpenRouter key available');
      return;
    }

    // flutter_test mocks the global HttpClient to always return empty 400s;
    // temporarily restore the real client for this test.
    final savedOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      final raw = await http.get(
        Uri.parse('https://openrouter.ai/api/v1/models'),
        headers: {'Authorization': 'Bearer $key'},
      );
      print('Raw GET /models -> ${raw.statusCode}');
      if (raw.statusCode != 200) {
        print(
          'Raw body: ${raw.body.substring(0, raw.body.length.clamp(0, 300))}',
        );
      }

      final service = OpenRouterService(apiKey: key);
      final models = await service.getAvailableModels();

      expect(raw.statusCode, 200, reason: 'raw models request failed');
      expect(models, isNotEmpty);
      // OpenRouter ids are "vendor/model"
      expect(models.first, contains('/'));

      final vendors = models.map((m) => m.split('/')[0]).toSet();
      expect(vendors.length, greaterThan(3));
      print(
        'Live OK: ${models.length} models across ${vendors.length} vendors',
      );
    } finally {
      HttpOverrides.global = savedOverrides;
    }
  }, timeout: Timeout(Duration(seconds: 30)));
}
