import 'package:flutter_test/flutter_test.dart';
import 'package:docan/models/conversation.dart';
import 'package:docan/models/usage_stats.dart';
import 'package:docan/services/openai_service.dart';
import 'package:docan/services/openrouter_service.dart';

void main() {
  group('UsageStats serialization', () {
    test('round-trips the nested provider/model map', () {
      final stats = {
        'openrouter': {
          'openai/gpt-4o': UsageStats()
            ..promptTokens = 120
            ..completionTokens = 340
            ..totalTokens = 460
            ..costUsd = 0.0042
            ..requests = 2,
        },
      };
      final restored = usageStatsFromJson(usageStatsToJson(stats));
      final model = restored['openrouter']!['openai/gpt-4o']!;
      expect(model.promptTokens, 120);
      expect(model.completionTokens, 340);
      expect(model.totalTokens, 460);
      expect(model.costUsd, closeTo(0.0042, 1e-9));
      expect(model.requests, 2);
    });

    test('empty and invalid input yield an empty map', () {
      expect(usageStatsFromJson(''), isEmpty);
      expect(usageStatsFromJson('not json'), isEmpty);
    });

    test('aggregates across models', () {
      final total = UsageStats()
        ..addAll(UsageStats()
          ..promptTokens = 10
          ..completionTokens = 20
          ..totalTokens = 30
          ..costUsd = 0.01
          ..requests = 1)
        ..addAll(UsageStats()
          ..promptTokens = 5
          ..completionTokens = 7
          ..totalTokens = 12
          ..costUsd = 0.02
          ..requests = 1);
      expect(total.promptTokens, 15);
      expect(total.completionTokens, 27);
      expect(total.totalTokens, 42);
      expect(total.costUsd, closeTo(0.03, 1e-9));
      expect(total.requests, 2);
    });

    test('Conversation serializes its usage stats', () {
      final conv = Conversation.create(title: 'chat')
          .copyWith(usage: UsageStats()
        ..promptTokens = 5
        ..completionTokens = 7
        ..totalTokens = 12
        ..costUsd = 0.0125
        ..requests = 1);
      final restored = Conversation.fromJson(conv.toJson());
      expect(restored.usage, isNotNull);
      expect(restored.usage!.totalTokens, 12);
      expect(restored.usage!.costUsd, closeTo(0.0125, 1e-9));
      expect(restored.usage!.requests, 1);
    });
  });

  group('OpenAIService.parseUsageChunk', () {
    test('parses a usage-only final chunk', () {
      final usage = OpenAIService.parseUsageChunk({
        'choices': [],
        'usage': {
          'prompt_tokens': 100,
          'completion_tokens': 50,
          'total_tokens': 150,
        },
      });
      expect(usage, isNotNull);
      expect(usage!.promptTokens, 100);
      expect(usage.completionTokens, 50);
      expect(usage.totalTokens, 150);
      expect(usage.costUsd, isNull);
    });

    test('parses OpenRouter cost when present', () {
      final usage = OpenAIService.parseUsageChunk({
        'usage': {
          'prompt_tokens': 10,
          'completion_tokens': 20,
          'total_tokens': 30,
          'cost': 0.00025,
        },
      });
      expect(usage!.costUsd, closeTo(0.00025, 1e-9));
    });

    test('returns null when usage is absent or all zeros', () {
      expect(OpenAIService.parseUsageChunk({'choices': []}), isNull);
      expect(
        OpenAIService.parseUsageChunk({
          'usage': {'prompt_tokens': 0, 'completion_tokens': 0},
        }),
        isNull,
      );
    });
  });

  group('OpenRouterService.parseModelPricing', () {
    test('converts per-token strings to per-million rates', () {
      final pricing = OpenRouterService.parseModelPricing({
        'id': 'openai/gpt-4o',
        'pricing': {'prompt': '0.000003', 'completion': '0.000015'},
      });
      expect(pricing!.promptPerMillion, closeTo(3.0, 1e-9));
      expect(pricing.completionPerMillion, closeTo(15.0, 1e-9));
    });

    test('returns null when pricing is missing or malformed', () {
      expect(OpenRouterService.parseModelPricing({'id': 'x'}), isNull);
      expect(
        OpenRouterService.parseModelPricing({
          'id': 'x',
          'pricing': {'prompt': 'free'},
        }),
        isNull,
      );
    });
  });

  group('OpenRouterService.parseKeyInfo', () {
    test('computes the remaining balance from usage and limit', () {
      final balance = OpenRouterService.parseKeyInfo({
        'usage': 7.66,
        'limit': 20.0,
      });
      expect(balance!.used, 7.66);
      expect(balance.limit, 20.0);
      expect(balance.remaining, closeTo(12.34, 1e-9));
    });

    test('remaining is null when no limit is set', () {
      final balance = OpenRouterService.parseKeyInfo({'usage': 3.0});
      expect(balance!.limit, isNull);
      expect(balance.remaining, isNull);
    });

    test('returns null when usage is absent', () {
      expect(OpenRouterService.parseKeyInfo({'limit': 20.0}), isNull);
    });

    test('accepts numeric-string usage and limit', () {
      final balance = OpenRouterService.parseKeyInfo({
        'usage': '7.66',
        'limit': '20',
      });
      expect(balance!.remaining, closeTo(12.34, 1e-9));
    });

    test('withSpent decrements the remaining balance', () {
      final balance = OpenRouterService.parseKeyInfo({
        'usage': 7.66,
        'limit': 20.0,
      });
      final after = balance!.withSpent(0.34);
      expect(after.remaining, closeTo(12.0, 1e-9));
    });
  });
}
