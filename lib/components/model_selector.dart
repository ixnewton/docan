import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/ai_provider.dart';

/// Model and provider selector dropdown
class ModelSelector extends StatefulWidget {
  final AIProvider selectedProvider;
  final String selectedModel;
  final ValueChanged<AIProvider> onProviderChanged;
  final ValueChanged<String> onModelChanged;
  final bool compact;
  final Map<AIProvider, bool>? configuredProviders;
  final Future<List<String>> Function(AIProvider)? fetchModels;

  const ModelSelector({
    super.key,
    required this.selectedProvider,
    required this.selectedModel,
    required this.onProviderChanged,
    required this.onModelChanged,
    this.compact = false,
    this.configuredProviders,
    this.fetchModels,
  });

  @override
  State<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<ModelSelector> {
  List<String>? _cachedModels;
  AIProvider? _cachedProvider;
  String? _vendor; // OpenRouter vendor ("provider") filter

  @override
  void didUpdateWidget(ModelSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProvider != widget.selectedProvider) {
      _vendor = _modelVendor(widget.selectedModel);
    }
  }

  /// Extract the OpenRouter vendor prefix from a "vendor/model" id
  String? _modelVendor(String modelId) {
    final index = modelId.indexOf('/');
    return index > 0 ? modelId.substring(0, index) : null;
  }

  bool _isProviderConfigured(AIProvider provider) {
    if (widget.configuredProviders == null) return true;
    return widget.configuredProviders![provider] ?? false;
  }

  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }

  Future<List<String>> _getModels() async {
    // Return cached if same provider
    if (_cachedModels != null && _cachedProvider == widget.selectedProvider) {
      return _cachedModels!;
    }

    if (widget.fetchModels != null) {
      final models = await widget.fetchModels!(widget.selectedProvider);
      _cachedModels = models;
      _cachedProvider = widget.selectedProvider;
      return models;
    }

    return widget.selectedProvider.availableModels;
  }

  /// Models visible in the model picker (filtered to the OpenRouter vendor)
  Future<List<String>> _getVisibleModels() async {
    final models = await _getModels();
    if (widget.selectedProvider == AIProvider.openrouter && _vendor != null) {
      return models.where((m) => _modelVendor(m) == _vendor).toList();
    }
    return models;
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
          icon: widget.selectedProvider.icon,
          label: widget.compact ? null : widget.selectedProvider.displayName,
          color: widget.selectedProvider.color,
          onTap: (buttonContext) => _showProviderPicker(context, buttonContext),
        ),
        // OpenRouter vendor ("provider") selector — only when OpenRouter is active
        if (widget.selectedProvider == AIProvider.openrouter) ...[
          const SizedBox(width: AppConstants.spacingS),
          _SelectorButton(
            icon: Icons.category,
            label: widget.compact ? null : (_vendor ?? 'Provider'),
            color: isDark ? Colors.white70 : Colors.black54,
            onTap: (buttonContext) => _showVendorPicker(context, buttonContext),
          ),
        ],
        const SizedBox(width: AppConstants.spacingS),
        // Model selector
        _SelectorButton(
          icon: Icons.memory,
          label: widget.compact
              ? null
              : _getModelDisplayName(widget.selectedModel),
          color: isDark ? Colors.white70 : Colors.black54,
          onTap: (buttonContext) => _showModelPicker(context, buttonContext),
        ),
      ],
    );
  }

  String _getModelDisplayName(String modelId) {
    // OpenRouter ids are "vendor/model" — show the model part
    if (modelId.contains('/')) {
      final suffix = modelId.split('/')[1];
      return suffix.length > 14 ? '${suffix.substring(0, 12)}...' : suffix;
    }
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

  void _showProviderPicker(BuildContext context, BuildContext buttonContext) {
    if (_isDesktop(context)) {
      _showProviderDropdown(context, buttonContext);
    } else {
      _showProviderBottomSheet(context);
    }
  }

  void _showProviderDropdown(BuildContext context, BuildContext buttonContext) {
    final RenderBox button = buttonContext.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(
      Offset(0, button.size.height),
      ancestor: overlay,
    );

    showMenu<AIProvider>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + 4,
        offset.dx + button.size.width,
        offset.dy + 4,
      ),
      items: AIProvider.values.map((provider) {
        final isConfigured = _isProviderConfigured(provider);
        return PopupMenuItem<AIProvider>(
          value: provider,
          enabled: isConfigured,
          child: Row(
            children: [
              Icon(
                provider.icon,
                size: 20,
                color: isConfigured ? provider.color : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.displayName,
                      style: TextStyle(
                        color: isConfigured ? null : Colors.grey,
                      ),
                    ),
                    if (!isConfigured)
                      Text(
                        'Not configured',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
              if (provider == widget.selectedProvider)
                Icon(
                  Icons.check,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                )
              else if (!isConfigured)
                const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
            ],
          ),
        );
      }).toList(),
    ).then((provider) {
      if (provider != null) {
        _cachedModels = null; // Clear cache when provider changes
        _cachedProvider = null;
        _vendor = _modelVendor(widget.selectedModel);
        widget.onProviderChanged(provider);
      }
    });
  }

  void _showProviderBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusL),
          ),
        ),
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
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: AIProvider.values.map((provider) {
                    final isConfigured = _isProviderConfigured(provider);
                    return ListTile(
                      leading: Icon(
                        provider.icon,
                        color: isConfigured ? provider.color : Colors.grey,
                      ),
                      title: Text(
                        provider.displayName,
                        style: TextStyle(
                          color: isConfigured ? null : Colors.grey,
                        ),
                      ),
                      subtitle: Text(
                        isConfigured
                            ? provider.description
                            : 'Not configured - add API key in Settings',
                        style: TextStyle(
                          color: isConfigured ? null : Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                      trailing: provider == widget.selectedProvider
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).primaryColor,
                            )
                          : !isConfigured
                          ? const Icon(
                              Icons.lock_outline,
                              color: Colors.grey,
                              size: 18,
                            )
                          : null,
                      enabled: isConfigured,
                      onTap: isConfigured
                          ? () {
                              _cachedModels = null;
                              _cachedProvider = null;
                              _vendor = _modelVendor(widget.selectedModel);
                              widget.onProviderChanged(provider);
                              Navigator.pop(context);
                            }
                          : null,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
          ],
        ),
      ),
    );
  }

  void _showModelPicker(BuildContext context, BuildContext buttonContext) {
    if (_isDesktop(context)) {
      _showModelDropdown(context, buttonContext);
    } else {
      _showModelBottomSheet(context);
    }
  }

  void _showVendorPicker(BuildContext context, BuildContext buttonContext) {
    if (_isDesktop(context)) {
      _showVendorDropdown(context, buttonContext);
    } else {
      _showVendorBottomSheet(context);
    }
  }

  /// OpenRouter vendor ("provider") dropdown for desktop
  void _showVendorDropdown(
    BuildContext context,
    BuildContext buttonContext,
  ) async {
    final RenderBox button = buttonContext.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(
      Offset(0, button.size.height),
      ancestor: overlay,
    );

    final models = await _getModels();
    if (!context.mounted) return;

    final vendors = models
        .map(_modelVendor)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + 4,
        offset.dx + button.size.width,
        offset.dy + 4,
      ),
      items: vendors.map((vendor) {
        return PopupMenuItem<String>(
          value: vendor,
          child: Row(
            children: [
              Icon(
                Icons.category,
                size: 18,
                color: widget.selectedProvider.color,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(vendor)),
              if (vendor == _vendor)
                Icon(
                  Icons.check,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
            ],
          ),
        );
      }).toList(),
    ).then((vendor) {
      if (vendor != null && vendor != _vendor) {
        setState(() => _vendor = vendor);
        // Keep the model consistent with the chosen vendor
        final candidates = models
            .where((m) => _modelVendor(m) == vendor)
            .toList();
        if (candidates.isNotEmpty &&
            _modelVendor(widget.selectedModel) != vendor) {
          widget.onModelChanged(candidates.first);
        }
      }
    });
  }

  /// OpenRouter vendor ("provider") bottom sheet for mobile
  void _showVendorBottomSheet(BuildContext context) async {
    final models = await _getModels();
    if (!context.mounted) return;

    final vendors = models
        .map(_modelVendor)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusL),
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
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
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: vendors.length,
                  itemBuilder: (context, index) {
                    final vendor = vendors[index];
                    return ListTile(
                      leading: Icon(
                        Icons.category,
                        color: widget.selectedProvider.color,
                      ),
                      title: Text(vendor),
                      trailing: vendor == _vendor
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).primaryColor,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        if (vendor != _vendor) {
                          setState(() => _vendor = vendor);
                          final candidates = models
                              .where((m) => _modelVendor(m) == vendor)
                              .toList();
                          if (candidates.isNotEmpty &&
                              _modelVendor(widget.selectedModel) != vendor) {
                            widget.onModelChanged(candidates.first);
                          }
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppConstants.spacingM),
            ],
          ),
        ),
      ),
    );
  }

  void _showModelDropdown(
    BuildContext context,
    BuildContext buttonContext,
  ) async {
    final RenderBox button = buttonContext.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(
      Offset(0, button.size.height),
      ancestor: overlay,
    );

    final models = await _getVisibleModels();

    if (!context.mounted) return;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + 4,
        offset.dx + button.size.width,
        offset.dy + 4,
      ),
      items: models.map((model) {
        return PopupMenuItem<String>(
          value: model,
          child: Row(
            children: [
              Icon(
                Icons.memory,
                size: 18,
                color: widget.selectedProvider.color,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(model)),
              if (model == widget.selectedModel)
                Icon(
                  Icons.check,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
            ],
          ),
        );
      }).toList(),
    ).then((model) {
      if (model != null) {
        widget.onModelChanged(model);
      }
    });
  }

  void _showModelBottomSheet(BuildContext context) async {
    final models = await _getVisibleModels();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusL),
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
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
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: models.length,
                  itemBuilder: (context, index) {
                    final model = models[index];
                    return ListTile(
                      leading: Icon(
                        Icons.memory,
                        color: widget.selectedProvider.color,
                      ),
                      title: Text(model),
                      trailing: model == widget.selectedModel
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).primaryColor,
                            )
                          : null,
                      onTap: () {
                        widget.onModelChanged(model);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppConstants.spacingM),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final Color color;
  final void Function(BuildContext) onTap;

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
        onTap: () => widget.onTap(context),
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
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.1,
              ),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: widget.color),
              if (widget.label != null) ...[
                const SizedBox(width: AppConstants.spacingS),
                Text(widget.label!, style: theme.textTheme.labelMedium),
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
