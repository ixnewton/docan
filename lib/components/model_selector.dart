import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/ai_provider.dart';
import '../utils/liquid_glass_effects.dart';

/// Model and provider selector dropdown
class ModelSelector extends StatelessWidget {
  final AIProvider selectedProvider;
  final String selectedModel;
  final ValueChanged<AIProvider> onProviderChanged;
  final ValueChanged<String> onModelChanged;
  final bool compact;
  final Map<AIProvider, bool>? configuredProviders;

  const ModelSelector({
    super.key,
    required this.selectedProvider,
    required this.selectedModel,
    required this.onProviderChanged,
    required this.onModelChanged,
    this.compact = false,
    this.configuredProviders,
  });

  bool _isProviderConfigured(AIProvider provider) {
    if (configuredProviders == null) return true;
    return configuredProviders![provider] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Provider selector
        _SelectorButton(
          icon: selectedProvider.icon,
          label: compact ? null : selectedProvider.displayName,
          color: selectedProvider.color,
          onTap: () => _showProviderPicker(context),
        ),
        const SizedBox(width: AppConstants.spacingS),
        // Model selector
        _SelectorButton(
          icon: Icons.memory,
          label: compact ? null : _getModelDisplayName(selectedModel),
          color: isDark ? Colors.white70 : Colors.black54,
          onTap: () => _showModelPicker(context),
        ),
      ],
    );
  }

  String _getModelDisplayName(String modelId) {
    // Shorten model names for display
    if (modelId.contains('gemini')) {
      if (modelId.contains('flash')) return 'Flash';
      if (modelId.contains('pro')) return 'Pro';
      return 'Gemini';
    }
    if (modelId.contains('gpt-4o-mini')) return '4o Mini';
    if (modelId.contains('gpt-4o')) return 'GPT-4o';
    if (modelId.contains('gpt-4')) return 'GPT-4';
    if (modelId.contains('gpt-3.5')) return 'GPT-3.5';
    if (modelId.contains('claude-sonnet-4')) return 'Sonnet 4';
    if (modelId.contains('claude-3-5-sonnet')) return 'Sonnet 3.5';
    if (modelId.contains('claude-3-5-haiku')) return 'Haiku';
    if (modelId.contains('llama')) return 'Llama';
    if (modelId.contains('mistral')) return 'Mistral';
    return modelId.length > 12 ? '${modelId.substring(0, 10)}...' : modelId;
  }

  void _showProviderPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => LiquidGlassContainer(
        borderRadius: AppConstants.radiusL,
        margin: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Text(
                'Select Provider',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            ...AIProvider.values.map((provider) => ListTile(
                  leading: Icon(
                    provider.icon,
                    color: provider.color,
                  ),
                  title: Text(provider.displayName),
                  subtitle: Text(provider.description),
                  trailing: provider == selectedProvider
                      ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                      : null,
                  onTap: () {
                    onProviderChanged(provider);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: AppConstants.spacingM),
          ],
        ),
      ),
    );
  }

  void _showModelPicker(BuildContext context) {
    final models = selectedProvider.availableModels;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => LiquidGlassContainer(
        borderRadius: AppConstants.radiusL,
        margin: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Text(
                'Select Model',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            ...models.map((model) => ListTile(
                  leading: Icon(
                    Icons.memory,
                    color: selectedProvider.color,
                  ),
                  title: Text(model),
                  trailing: model == selectedModel
                      ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                      : null,
                  onTap: () {
                    onModelChanged(model);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: AppConstants.spacingM),
          ],
        ),
      ),
    );
  }
}

class _SelectorButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final Color color;
  final VoidCallback onTap;

  const _SelectorButton({
    required this.icon,
    this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_SelectorButton> createState() => _SelectorButtonState();
}

class _SelectorButtonState extends State<_SelectorButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppConstants.hoverDuration,
          padding: EdgeInsets.symmetric(
            horizontal: widget.label != null
                ? AppConstants.spacingM
                : AppConstants.spacingS,
            vertical: AppConstants.spacingS,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.radiusS),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: widget.color),
              if (widget.label != null) ...[
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  widget.label!,
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(width: AppConstants.spacingXS),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
