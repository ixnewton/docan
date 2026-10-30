import 'package:flutter/material.dart';

import '../models/ai_provider.dart';
import '../models/usage_stats.dart';

class CreditChip extends StatelessWidget {
  final AIProvider provider;
  final CreditBalance? balance;

  const CreditChip({super.key, required this.provider, this.balance});

  @override
  Widget build(BuildContext context) {
    final remaining = balance?.remaining;
    if (remaining == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white70 : Colors.black54;
    return Tooltip(
      message:
          '${provider.displayName} credit balance: \$${remaining.toStringAsFixed(2)} '
          'remaining of \$${balance!.limit!.toStringAsFixed(2)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              '\$${remaining.toStringAsFixed(2)} left',
              style: theme.textTheme.bodySmall?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class UsageChip extends StatelessWidget {
  final AIProvider provider;
  final UsageStats? usage;
  final String? label;

  const UsageChip({
    super.key,
    required this.provider,
    this.usage,
    this.label,
  });

  static String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    }
    if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}k';
    }
    return '$tokens';
  }

  @override
  Widget build(BuildContext context) {
    final stats = usage;
    if (stats == null || stats.requests == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white70 : Colors.black54;
    final tooltip = '${label ?? '${provider.displayName} usage'}: '
        '${stats.promptTokens} in / ${stats.completionTokens} out tokens '
        'across ${stats.requests} requests'
        '${stats.costUsd > 0 ? ' · \$${stats.costUsd.toStringAsFixed(4)}' : ''}';
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.token_outlined, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              '${_formatTokens(stats.promptTokens)}↑ '
              '${_formatTokens(stats.completionTokens)}↓',
              style: theme.textTheme.bodySmall?.copyWith(color: fg),
            ),
            if (stats.costUsd > 0) ...[
              const SizedBox(width: 6),
              Text(
                '\$${stats.costUsd.toStringAsFixed(stats.costUsd < 1 ? 4 : 2)}',
                style: theme.textTheme.bodySmall?.copyWith(color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
