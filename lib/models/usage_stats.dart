import 'dart:convert';

class TokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final double? costUsd;

  const TokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    this.costUsd,
  });

  factory TokenUsage.fromJson(Map<String, dynamic> json) => TokenUsage(
        promptTokens: (json['pt'] as num?)?.toInt() ?? 0,
        completionTokens: (json['ct'] as num?)?.toInt() ?? 0,
        totalTokens: (json['tt'] as num?)?.toInt() ?? 0,
        costUsd: (json['cost'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'pt': promptTokens,
        'ct': completionTokens,
        'tt': totalTokens,
        if (costUsd != null) 'cost': costUsd,
      };
}

class UsageStats {
  UsageStats();

  int promptTokens = 0;
  int completionTokens = 0;
  int totalTokens = 0;
  double costUsd = 0;
  int requests = 0;

  void add(TokenUsage usage) {
    promptTokens += usage.promptTokens;
    completionTokens += usage.completionTokens;
    totalTokens += usage.totalTokens;
    costUsd += usage.costUsd ?? 0;
    requests += 1;
  }

  void addAll(UsageStats other) {
    promptTokens += other.promptTokens;
    completionTokens += other.completionTokens;
    totalTokens += other.totalTokens;
    costUsd += other.costUsd;
    requests += other.requests;
  }

  Map<String, dynamic> toJson() => {
        'pt': promptTokens,
        'ct': completionTokens,
        'tt': totalTokens,
        'cost': costUsd,
        'req': requests,
      };

  factory UsageStats.fromJson(Map<String, dynamic> json) => UsageStats()
    ..promptTokens = (json['pt'] as num?)?.toInt() ?? 0
    ..completionTokens = (json['ct'] as num?)?.toInt() ?? 0
    ..totalTokens = (json['tt'] as num?)?.toInt() ?? 0
    ..costUsd = (json['cost'] as num?)?.toDouble() ?? 0
    ..requests = (json['req'] as num?)?.toInt() ?? 0;
}

class ModelPricing {
  final double promptPerMillion;
  final double completionPerMillion;

  const ModelPricing({
    required this.promptPerMillion,
    required this.completionPerMillion,
  });
}

class CreditBalance {
  final double used;
  final double? limit;

  const CreditBalance({required this.used, this.limit});

  double? get remaining => limit == null ? null : limit! - used;

  CreditBalance withSpent(double cost) =>
      CreditBalance(used: used + cost, limit: limit);
}

Map<String, Map<String, UsageStats>> usageStatsFromJson(String raw) {
  final result = <String, Map<String, UsageStats>>{};
  if (raw.isEmpty) return result;
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    decoded.forEach((provider, models) {
      if (models is Map<String, dynamic>) {
        result[provider] = models.map(
          (model, stats) => MapEntry(
            model,
            UsageStats.fromJson(stats as Map<String, dynamic>),
          ),
        );
      }
    });
  } catch (_) {
    return {};
  }
  return result;
}

String usageStatsToJson(Map<String, Map<String, UsageStats>> stats) {
  return jsonEncode(stats.map(
    (provider, models) => MapEntry(
      provider,
      models.map((model, stats) => MapEntry(model, stats.toJson())),
    ),
  ));
}
