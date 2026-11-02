import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/ai_provider.dart';
import '../models/usage_stats.dart';

/// Provider descriptor for the selector, decoupling it from any specific
/// provider enum so the same component serves chat (AIProvider) and image
/// (ImageGenProvider) contexts.
class SelectorProviderInfo {
  final String id;
  final String displayName;
  final String? description;
  final IconData icon;
  final Color color;
  final ProviderStatus status;
  final List<String>? models;

  const SelectorProviderInfo({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.color,
    this.description,
    this.status = ProviderStatus.available,
    this.models,
  });
}

extension AIProviderDescriptor on AIProvider {
  SelectorProviderInfo toDescriptor(ProviderStatus status) {
    return SelectorProviderInfo(
      id: name,
      displayName: displayName,
      description: description,
      icon: icon,
      color: color,
      status: status,
    );
  }
}

/// Model and provider selector dropdown
class ModelSelector extends StatefulWidget {
  final List<SelectorProviderInfo> providers;
  final String selectedProviderId;
  final String selectedModel;
  final ValueChanged<String> onProviderChanged;
  final ValueChanged<String> onModelChanged;
  final bool compact;
  final Future<List<SelectorProviderInfo>> Function()? loadProviders;
  final Future<List<String>> Function(String providerId)? fetchModels;
  final Future<Map<String, String>> Function(String providerId)?
      fetchVendorIcons;
  final Future<Map<String, ModelPricing>> Function(String providerId)?
      fetchModelPricing;
  final bool showVendorFilter;

  const ModelSelector({
    super.key,
    required this.providers,
    required this.selectedProviderId,
    required this.selectedModel,
    required this.onProviderChanged,
    required this.onModelChanged,
    this.compact = false,
    this.loadProviders,
    this.fetchModels,
    this.fetchVendorIcons,
    this.fetchModelPricing,
    this.showVendorFilter = false,
  });

  @override
  State<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<ModelSelector> {
  List<String>? _cachedModels;
  String? _cachedProviderId;
  String? _vendor; // OpenRouter vendor ("provider") filter
  Map<String, ModelPricing>? _modelPricing;

  SelectorProviderInfo get _selectedDescriptor {
    return widget.providers.firstWhere(
      (p) => p.id == widget.selectedProviderId,
      orElse: () => SelectorProviderInfo(
        id: widget.selectedProviderId,
        displayName: widget.selectedProviderId,
        icon: Icons.extension,
        color: Colors.grey,
      ),
    );
  }

  bool get _vendorFilterActive =>
      widget.showVendorFilter && widget.selectedProviderId == 'openrouter';

  @override
  void initState() {
    super.initState();
    _vendor = _modelVendor(widget.selectedModel);
    _loadPricing();
  }

  @override
  void didUpdateWidget(ModelSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProviderId != widget.selectedProviderId ||
        _modelVendor(widget.selectedModel) != _vendor) {
      _vendor = _modelVendor(widget.selectedModel);
    }
    if (oldWidget.selectedProviderId != widget.selectedProviderId) {
      _modelPricing = null;
      _loadPricing();
    }
  }

  Future<void> _loadPricing() async {
    if (!_vendorFilterActive || widget.fetchModelPricing == null) {
      return;
    }
    try {
      final pricing =
          await widget.fetchModelPricing!(widget.selectedProviderId);
      if (mounted && pricing.isNotEmpty) {
        setState(() => _modelPricing = pricing);
      }
    } catch (_) {
      if (mounted) _modelPricing = null;
    }
  }

  /// Extract the OpenRouter vendor prefix from a "vendor/model" id
  String? _modelVendor(String modelId) {
    final index = modelId.indexOf('/');
    return index > 0 ? modelId.substring(0, index) : null;
  }

  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }

  Future<List<String>> _getModels() async {
    // Return cached if same provider
    if (_cachedModels != null && _cachedProviderId == widget.selectedProviderId) {
      return _cachedModels!;
    }

    if (widget.fetchModels != null) {
      final models = await widget.fetchModels!(widget.selectedProviderId);
      _cachedModels = models;
      _cachedProviderId = widget.selectedProviderId;
      return models;
    }

    return _selectedDescriptor.models ?? const [];
  }

  /// Models visible in the model picker (filtered to the OpenRouter vendor)
  Future<List<String>> _getVisibleModels() async {
    final models = await _getModels();
    if (_vendorFilterActive && _vendor != null) {
      return models.where((m) => _modelVendor(m) == _vendor).toList();
    }
    return models;
  }

  /// Vendor icon for the menu (favicon image, generic icon as fallback)
  Widget _vendorIcon(String vendor, Map<String, String> icons, Color color) {
    final url =
        icons[vendor] ?? icons[vendor.replaceFirst('~', '')];
    if (url == null) {
      return Icon(Icons.category, size: 18, color: color);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url,
        width: 18,
        height: 18,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(Icons.category, size: 18, color: color),
      ),
    );
  }

  /// Fetch vendor icons when available
  Future<Map<String, String>> _getVendorIcons() async {
    if (widget.fetchVendorIcons == null) return const {};
    try {
      return await widget.fetchVendorIcons!(widget.selectedProviderId);
    } catch (_) {
      return const {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selected = _selectedDescriptor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Provider selector
        SelectorButton(
          icon: selected.icon,
          label: widget.compact ? null : selected.displayName,
          color: selected.color,
          onTap: (buttonContext) => _showProviderPicker(context, buttonContext),
        ),
        // OpenRouter vendor ("provider") selector — only when active
        if (_vendorFilterActive) ...[
          const SizedBox(width: AppConstants.spacingS),
          SelectorButton(
            icon: Icons.category,
            label: widget.compact ? null : (_vendor ?? 'Provider'),
            color: isDark ? Colors.white70 : Colors.black54,
            onTap: (buttonContext) => _showVendorPicker(context, buttonContext),
          ),
        ],
        const SizedBox(width: AppConstants.spacingS),
        // Model selector
        SelectorButton(
          icon: Icons.memory,
          label: widget.compact
              ? null
              : _getModelDisplayName(widget.selectedModel),
          sublabel: widget.compact
              ? null
              : _selectedModelPricingLabel(),
          color: isDark ? Colors.white70 : Colors.black54,
          onTap: (buttonContext) => _showModelPicker(context, buttonContext),
        ),
      ],
    );
  }

  String? _selectedModelPricingLabel() {
    final rate = _modelPricing?[widget.selectedModel];
    return rate == null ? null : _pricingLabel(rate);
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
    _openProviderMenu(context, buttonContext);
  }

  /// Refresh the provider list before opening the menu so local-server
  /// state (running / not running) is current
  Future<void> _openProviderMenu(
    BuildContext context,
    BuildContext buttonContext,
  ) async {
    List<SelectorProviderInfo>? fresh;
    if (widget.loadProviders != null) {
      try {
        fresh = await widget.loadProviders!();
      } catch (_) {
        fresh = null;
      }
    }
    if (!context.mounted) return;
    if (_isDesktop(context)) {
      _showProviderDropdown(context, buttonContext, fresh);
    } else {
      _showProviderBottomSheet(context, fresh);
    }
  }

  void _showProviderDropdown(
    BuildContext context,
    BuildContext buttonContext,
    List<SelectorProviderInfo>? fresh,
  ) {
    final RenderBox button = buttonContext.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(
      Offset(0, button.size.height),
      ancestor: overlay,
    );
    final effective = fresh ?? widget.providers;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + 4,
        offset.dx + button.size.width,
        offset.dy + 4,
      ),
      items: effective
          .where((p) => p.status != ProviderStatus.notConfigured)
          .map((provider) {
        final stopped = provider.status == ProviderStatus.stopped;
        return PopupMenuItem<String>(
          value: provider.id,
          enabled: !stopped,
          child: Row(
            children: [
              Icon(
                provider.icon,
                size: 20,
                color: stopped ? Colors.grey : provider.color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.displayName,
                      style: TextStyle(color: stopped ? Colors.grey : null),
                    ),
                    if (stopped)
                      Text(
                        'Not running',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
              if (provider.id == widget.selectedProviderId)
                Icon(
                  Icons.check,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
            ],
          ),
        );
      }).toList(),
    ).then((providerId) {
      if (providerId != null) {
        _cachedModels = null; // Clear cache when provider changes
        _cachedProviderId = null;
        _vendor = _modelVendor(widget.selectedModel);
        widget.onProviderChanged(providerId);
      }
    });
  }

  void _showProviderBottomSheet(
    BuildContext context,
    List<SelectorProviderInfo>? fresh,
  ) {
    final effective = fresh ?? widget.providers;
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
                  children: effective
                      .where(
                        (p) => p.status != ProviderStatus.notConfigured,
                      )
                      .map((provider) {
                    final stopped =
                        provider.status == ProviderStatus.stopped;
                    return ListTile(
                      leading: Icon(
                        provider.icon,
                        color: stopped ? Colors.grey : provider.color,
                      ),
                      title: Text(
                        provider.displayName,
                        style: TextStyle(color: stopped ? Colors.grey : null),
                      ),
                      subtitle: Text(
                        stopped
                            ? 'Not running - start the service'
                            : (provider.description ?? ''),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                      trailing: provider.id == widget.selectedProviderId
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).primaryColor,
                            )
                          : null,
                      enabled: !stopped,
                      onTap: () {
                        _cachedModels = null;
                        _cachedProviderId = null;
                        _vendor = _modelVendor(widget.selectedModel);
                        widget.onProviderChanged(provider.id);
                        Navigator.pop(context);
                      },
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
    final icons = await _getVendorIcons();
    if (!context.mounted) return;

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
              _vendorIcon(vendor, icons, _selectedDescriptor.color),
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
    final icons = await _getVendorIcons();
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
                      leading: _vendorIcon(
                        vendor,
                        icons,
                        _selectedDescriptor.color,
                      ),
                      title: Text(vendor),
                      trailing: vendor == _vendor
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).primaryColor,
                            )
                          : null,
                      onTap: () {
                        setState(() => _vendor = vendor);
                        final candidates = models
                            .where((m) => _modelVendor(m) == vendor)
                            .toList();
                        if (candidates.isNotEmpty &&
                            _modelVendor(widget.selectedModel) != vendor) {
                          widget.onModelChanged(candidates.first);
                        }
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

  void _showModelDropdown(
    BuildContext context,
    BuildContext buttonContext,
  ) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final RenderBox button = buttonContext.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(
      Offset(0, button.size.height),
      ancestor: overlay,
    );

    final models = await _getVisibleModels();

    if (_modelPricing == null && widget.fetchModelPricing != null) {
      try {
        _modelPricing =
            await widget.fetchModelPricing!(widget.selectedProviderId);
      } catch (_) {
        _modelPricing = const {};
      }
    }
    final pricing = _modelPricing ?? const <String, ModelPricing>{};

    if (!context.mounted) return;

    // Let the menu grow rightward to fit its content (no ellipsis) until it
    // approaches the panel's right margin
    final overlaySize = overlay.size;
    final maxMenuWidth = math.max(
      112.0,
      overlaySize.width - offset.dx - 16,
    );

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + 4,
        offset.dx + button.size.width,
        offset.dy + 4,
      ),
      constraints: BoxConstraints(maxWidth: maxMenuWidth),
      items: models.map((model) {
        final rate = pricing[model];
        return PopupMenuItem<String>(
          value: model,
          child: Row(
            children: [
              Icon(
                Icons.memory,
                size: 18,
                color: widget.selectedProviderId == 'openrouter'
                    ? _selectedDescriptor.color
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  model,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (rate != null) ...[
                const SizedBox(width: 8),
                Text(
                  _pricingLabel(rate),
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
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

  String _pricingLabel(ModelPricing pricing) {
    String fmt(double v) {
      if (v >= 100) return '\$${v.toStringAsFixed(0)}';
      return '\$${v.toStringAsFixed(2)}';
    }
    return '${fmt(pricing.promptPerMillion)}/M in · ${fmt(pricing.completionPerMillion)}/M out';
  }

  void _showModelBottomSheet(BuildContext context) async {
    final models = await _getVisibleModels();

    if (_modelPricing == null && widget.fetchModelPricing != null) {
      try {
        _modelPricing =
            await widget.fetchModelPricing!(widget.selectedProviderId);
      } catch (_) {
        _modelPricing = const {};
      }
    }
    final modelPricing = _modelPricing ?? const <String, ModelPricing>{};

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
                    final rate = modelPricing[model];
                    return ListTile(
                      leading: Icon(
                        Icons.memory,
                        color: widget.selectedProviderId == 'openrouter'
                            ? _selectedDescriptor.color
                            : Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(model),
                      subtitle: rate != null
                          ? Text(
                              _pricingLabel(rate),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color
                                            ?.withValues(alpha: 0.7),
                                  ),
                            )
                          : null,
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

class SelectorButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final String? sublabel;
  final Color color;
  final void Function(BuildContext) onTap;

  const SelectorButton({
    super.key,
    required this.icon,
    this.label,
    this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  State<SelectorButton> createState() => _SelectorButtonState();
}

class _SelectorButtonState extends State<SelectorButton> {
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
                if (widget.sublabel != null) ...[
                  const SizedBox(width: AppConstants.spacingXS),
                  Text(
                    widget.sublabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
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
