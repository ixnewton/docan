import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../models/ai_provider.dart';
import '../../components/comfyui_settings_panel.dart';
import '../../components/model_selector.dart';
import '../../services/clipboard_service.dart';
import '../../services/chat_service.dart';
import '../../services/image_generation_service.dart';
import '../../components/usage_chip.dart';
import '../../utils/image_exit_guard.dart';
import '../../utils/prompt_history.dart';

/// Desktop image generation screen
class DesktopImageScreen extends StatefulWidget {
  const DesktopImageScreen({super.key});

  @override
  State<DesktopImageScreen> createState() => _DesktopImageScreenState();
}

class _DesktopImageScreenState extends State<DesktopImageScreen> {
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocusNode = FocusNode();
  Map<ImageGenProvider, bool> _configuredProviders = {};
  ImageSize _selectedSize = ImageSize.large;
  GeneratedImage? _selectedImage;
  bool _showComfyUISettings = false;
  late final PromptHistory _promptHistory;
  Map<DateTime, List<SavedImageRecord>>? _historyByDay;
  String? _historyFolder;
  DateTime? _expandedDay;
  SavedImageRecord? _selectedHistoryRecord;
  final Set<String> _savedImageIds = <String>{};

  @override
  void initState() {
    super.initState();
    _promptHistory = PromptHistory(
      controller: _promptController,
      promptsProvider: () {
        final service = context.read<ImageGenerationService>();
        // Oldest first: the saved history, then this session's images
        final prompts = [
          ...service.imageHistory.map((r) => r.prompt),
          ...service.generatedImages.reversed.map((i) => i.prompt),
        ];
        final seen = <String>{};
        return [
          for (final prompt in prompts)
            if (prompt.trim().isNotEmpty && seen.add(prompt)) prompt,
        ];
      },
    );
    _promptFocusNode.onKeyEvent = _promptHistory.handleKeyEvent;
    _loadConfiguredProviders();
    _refreshHistory();
    ImageExitGuard.register(_confirmExit);
  }

  @override
  void dispose() {
    ImageExitGuard.unregister();
    _promptController.dispose();
    _promptFocusNode.dispose();
    super.dispose();
  }

  Future<void> _refreshHistory() async {
    final service = context.read<ImageGenerationService>();
    final folder = await service.resolveSaveFolder();
    final byDay = await service.historyByDay(folder: folder);
    if (mounted) {
      setState(() {
        _historyFolder = folder;
        _historyByDay = byDay;
      });
    }
  }

  Future<void> _loadConfiguredProviders() async {
    final service = context.read<ImageGenerationService>();
    final configured = await service.getConfiguredProviders();
    if (mounted) {
      setState(() {
        _configuredProviders = configured;
      });
    }
  }

  List<SelectorProviderInfo> _imageProviderDescriptors(
    BuildContext context,
    ImageGenerationService service, [
    Map<ImageGenProvider, bool>? configured,
  ]) {
    final effective = configured ?? _configuredProviders;
    final color = Theme.of(context).colorScheme.primary;
    return ImageGenProvider.values.map((p) {
      final isConfigured = effective[p] ?? false;
      return SelectorProviderInfo(
        id: p.name,
        displayName: p.displayName,
        description: p.description,
        icon: p.icon,
        color: color,
        status: isConfigured
            ? ProviderStatus.available
            : ProviderStatus.notConfigured,
      );
    }).toList();
  }

  Future<void> _generateImage() async {
    final service = context.read<ImageGenerationService>();
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    final image = await service.generateImage(prompt, size: _selectedSize);
    if (image != null && mounted) {
      final cost = service.lastGenerationCost;
      if (cost != null) {
        context.read<ChatService>().spendCredits(AIProvider.openrouter, cost);
      }
      _promptHistory.reset();
      setState(() {
        _selectedImage = image;
        _selectedHistoryRecord = null;
      });
    }
  }

  Future<void> _saveImage(GeneratedImage image) async {
    try {
      final service = context.read<ImageGenerationService>();
      final filePath = await service.saveImageToHistory(image);
      _savedImageIds.add(image.id);
      await _refreshHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image saved to $filePath'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save image: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Opens a saved history image in the main display
  Future<void> _openHistoryImage(SavedImageRecord record) async {
    if (_historyFolder == null) return;
    try {
      final bytes = await File(
        '$_historyFolder/${record.fileName}',
      ).readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImage = GeneratedImage(
          prompt: record.prompt,
          imageData: bytes,
          provider: ImageGenProvider.values.firstWhere(
            (p) => p.name == record.provider,
            orElse: () => ImageGenProvider.gemini,
          ),
          model: record.model,
          timestamp: record.savedAt,
        );
        _selectedHistoryRecord = record;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open image: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Deletes the currently displayed image: a history image loses its file
  /// and history record; a session image is removed from the session list
  Future<void> _deleteSelectedImage() async {
    final service = context.read<ImageGenerationService>();
    final record = _selectedHistoryRecord;
    if (record != null) {
      try {
        File('$_historyFolder/${record.fileName}').deleteSync();
      } catch (_) {}
      await service.deleteHistoryRecord(record);
      await _refreshHistory();
    } else {
      final image = _selectedImage;
      if (image != null) {
        service.deleteImage(image.id);
      }
    }
    if (mounted) {
      setState(() {
        _selectedImage = null;
        _selectedHistoryRecord = null;
      });
    }
  }

  /// Exit confirmation when unsaved session images exist. Returns true
  /// when the user chose to exit; "Select and save" simply closes the
  /// alert so the user can select and save images in the creator.
  Future<bool> _confirmExit() async {
    final service = context.read<ImageGenerationService>();
    final unsaved = service.generatedImages
        .where((image) => !_savedImageIds.contains(image.id))
        .toList();
    if (unsaved.isEmpty) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unsaved images'),
        content: const Text('Select and save images or Exit'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'exit'),
            child: const Text('Exit'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'stay'),
            child: const Text('Select and save'),
          ),
        ],
      ),
    );
    return result == 'exit';
  }

  Future<void> _copyImageToClipboard(GeneratedImage image) async {
    try {
      await ClipboardService.setText(image.prompt);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prompt copied to clipboard'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Clipboard failed
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<ImageGenerationService>(
      builder: (context, service, child) {
        final hasApiKey =
            _configuredProviders[service.selectedProvider] ?? false;
        final isComfyUI = service.selectedProvider == ImageGenProvider.comfyui;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              if (await _confirmExit() && context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Row(
              children: [
                // Sidebar with generated images
                _buildSidebar(context, service, isDark),

                // Main content
                Expanded(
                  child: Column(
                    children: [
                      // Toolbar
                      _buildToolbar(context, service),

                      // Image display area
                      Expanded(
                        child: Row(
                          children: [
                            // Image area
                            Expanded(child: _buildImageArea(context, service)),

                            // ComfyUI Settings Panel (only when ComfyUI is selected)
                            if (isComfyUI && _showComfyUISettings)
                              _buildComfyUISettingsPanel(
                                context,
                                service,
                                isDark,
                              ),
                          ],
                        ),
                      ),

                      // Prompt input
                      _buildPromptInput(context, service, hasApiKey),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComfyUISettingsPanel(
    BuildContext context,
    ImageGenerationService service,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.5),
        border: Border(
          left: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Row(
              children: [
                const Icon(Icons.tune, size: 18),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'ComfyUI Settings',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: 32,
                  onPressed: () {
                    setState(() {
                      _showComfyUISettings = false;
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Settings
          Expanded(
            child: ComfyUISettingsPanel(
              settings: service.comfyUISettings,
              onSettingsChanged: service.updateComfyUISettings,
              isCompact: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    ImageGenerationService service,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.5),
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to Chat',
                  onPressed: () async {
                    if (await _confirmExit() && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
                Icon(Icons.image, color: theme.primaryColor),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'Image Creator',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Image gallery: unsaved session images on top, then the saved
          // history grouped by day
          Expanded(
            child:
                (service.generatedImages.isEmpty &&
                    (_historyByDay == null || _historyByDay!.isEmpty))
                ? Center(
                    child: Text(
                      'No images yet',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppConstants.spacingS),
                    children: [
                      if (service.generatedImages.isNotEmpty) ...[
                        _sidebarSectionLabel(context, 'This session'),
                        ...service.generatedImages.map((image) {
                          final isSelected = _selectedImage?.id == image.id;
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppConstants.spacingS,
                            ),
                            child: _ImageThumbnail(
                              image: image,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  _selectedImage = image;
                                  _selectedHistoryRecord = null;
                                });
                              },
                              onDelete: () {
                                service.deleteImage(image.id);
                                _savedImageIds.remove(image.id);
                                if (_selectedImage?.id == image.id) {
                                  setState(() {
                                    _selectedImage =
                                        service.generatedImages.isNotEmpty
                                        ? service.generatedImages.first
                                        : null;
                                    _selectedHistoryRecord = null;
                                  });
                                }
                              },
                            ),
                          );
                        }),
                        const SizedBox(height: AppConstants.spacingM),
                      ],
                      if (_historyByDay != null)
                        ..._buildHistorySections(context),
                    ],
                  ),
          ),

          // Clear all button
          if (service.generatedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: TextButton.icon(
                onPressed: () {
                  service.clearImages();
                  setState(() {
                    _selectedImage = null;
                  });
                },
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sidebarSectionLabel(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppConstants.spacingS),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  /// Day/date sections for the saved history. By default only the newest
  /// day's thumbnails are shown; selecting a day label shows just that
  /// day's thumbnails (labels always remain).
  List<Widget> _buildHistorySections(BuildContext context) {
    final days = _historyByDay!.keys.toList();
    final newest = days.isNotEmpty ? days.first : null;
    final effectiveDay = _expandedDay ?? newest;

    return [
      _sidebarSectionLabel(context, 'Saved'),
      for (final day in days)
        _DaySection(
          day: day,
          records: _historyByDay![day]!,
          folder: _historyFolder ?? '',
          expanded: day == effectiveDay,
          onToggle: () {
            setState(() {
              _expandedDay = (day == _expandedDay) ? null : day;
            });
          },
          onOpen: _openHistoryImage,
        ),
    ];
  }

  Widget _buildToolbar(BuildContext context, ImageGenerationService service) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // Provider and model selector (image-capable providers only)
          ModelSelector(
            providers: _imageProviderDescriptors(context, service),
            selectedProviderId: service.selectedProvider.name,
            selectedModel: service.selectedModel,
            onProviderChanged: (id) => service.setProvider(
              ImageGenProvider.values.firstWhere((p) => p.name == id),
            ),
            onModelChanged: service.setModel,
            loadProviders: () async {
              final configured = await service.getConfiguredProviders();
              return _imageProviderDescriptors(context, service, configured);
            },
            fetchModels: (id) => service.getAvailableModels(
              ImageGenProvider.values.firstWhere((p) => p.name == id),
            ),
            fetchModelPricing: (id) => id == 'openrouter'
                ? context.read<ChatService>().getModelPricing(
                    AIProvider.openrouter,
                  )
                : Future.value(const {}),
            showVendorFilter: true,
          ),

          const Spacer(),

          // Image generation spend for this provider
          UsageChip(
            provider: AIProvider.openrouter,
            label: 'Image spend',
            usage: service.imageUsageForProvider(service.selectedProvider),
          ),
          const SizedBox(width: AppConstants.spacingS),

          // Credit balance (OpenRouter)
          CreditChip(
            provider: AIProvider.openrouter,
            balance: context.read<ChatService>().creditBalanceFor(
              AIProvider.openrouter,
            ),
          ),
          const SizedBox(width: AppConstants.spacingS),

          // ComfyUI Settings toggle (only when ComfyUI is selected)
          if (service.selectedProvider == ImageGenProvider.comfyui) ...[
            IconButton(
              icon: Icon(
                _showComfyUISettings ? Icons.tune : Icons.tune_outlined,
              ),
              tooltip: 'ComfyUI Settings',
              onPressed: () {
                setState(() {
                  _showComfyUISettings = !_showComfyUISettings;
                });
              },
            ),
            const SizedBox(width: AppConstants.spacingM),
          ],

          // Size selector (hide when ComfyUI is selected - it has its own resolution settings)
          if (service.selectedProvider != ImageGenProvider.comfyui) ...[
            _SizeSelector(
              selectedSize: _selectedSize,
              onChanged: (size) {
                setState(() {
                  _selectedSize = size;
                });
              },
            ),
            const SizedBox(width: AppConstants.spacingM),
          ],

          // Actions for selected image
          if (_selectedImage != null) ...[
            IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: 'Save Image',
              onPressed: () => _saveImage(_selectedImage!),
            ),
            const SizedBox(width: AppConstants.spacingS),
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy Prompt',
              onPressed: () => _copyImageToClipboard(_selectedImage!),
            ),
            const SizedBox(width: AppConstants.spacingS),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete displayed image',
              onPressed: _deleteSelectedImage,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageArea(BuildContext context, ImageGenerationService service) {
    final theme = Theme.of(context);

    if (service.isGenerating) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text('Generating image...', style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    if (service.error != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: AppConstants.spacingM),
              Text(
                'Error',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Text(
                service.error!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spacingM),
              TextButton(
                onPressed: service.clearError,
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedImage == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: 80,
              color: theme.iconTheme.color?.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Enter a prompt to generate an image',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return _ImageViewer(
      image: _selectedImage!,
      onSave: () => _saveImage(_selectedImage!),
    );
  }

  Widget _buildPromptInput(
    BuildContext context,
    ImageGenerationService service,
    bool hasApiKey,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _promptController,
              focusNode: _promptFocusNode,
              enabled: hasApiKey && !service.isGenerating,
              maxLines: 3,
              minLines: 1,
              onSubmitted: (_) => _generateImage(),
              decoration: InputDecoration(
                hintText: hasApiKey
                    ? 'Describe the image you want to create...'
                    : 'Add API key in settings to generate images',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingM),
          FilledButton.icon(
            onPressed: hasApiKey && !service.isGenerating
                ? _generateImage
                : null,
            icon: const Icon(Icons.auto_awesome, size: 20),
            label: const Text('Generate'),
          ),
        ],
      ),
    );
  }
}

/// Image thumbnail widget
class _ImageThumbnail extends StatelessWidget {
  final GeneratedImage image;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ImageThumbnail({
    required this.image,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusS),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusS - 2),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Image.memory(image.imageData, fit: BoxFit.cover),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Image viewer widget
class _ImageViewer extends StatelessWidget {
  final GeneratedImage image;
  final VoidCallback onSave;

  const _ImageViewer({required this.image, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      child: Column(
        children: [
          // Image
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(AppConstants.spacingS),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  child: Image.memory(image.imageData, fit: BoxFit.contain),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // Info
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      '${image.provider.displayName} - ${image.model}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTimestamp(image.timestamp),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  image.revisedPrompt ?? image.prompt,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Size selector
class _SizeSelector extends StatelessWidget {
  final ImageSize selectedSize;
  final ValueChanged<ImageSize> onChanged;

  const _SizeSelector({required this.selectedSize, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<ImageSize>(
      initialValue: selectedSize,
      onSelected: onChanged,
      itemBuilder: (context) {
        return ImageSize.values.map((size) {
          return PopupMenuItem<ImageSize>(
            value: size,
            child: Text(size.displayName),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingM,
          vertical: AppConstants.spacingS,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.aspect_ratio, size: 18),
            const SizedBox(width: AppConstants.spacingS),
            Text(selectedSize.displayName),
            const SizedBox(width: AppConstants.spacingS),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

/// A saved-history day section: the day/date label (always visible) with
/// the day's image thumbnails below it when expanded
class _DaySection extends StatelessWidget {
  final DateTime day;
  final List<SavedImageRecord> records;
  final String folder;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<SavedImageRecord> onOpen;

  const _DaySection({
    required this.day,
    required this.records,
    required this.folder,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
  });

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(day.year, day.month, day.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${target.day} ${_month(target)} ${target.year}';
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _month(DateTime d) => _months[d.month - 1];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusS),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: AppConstants.spacingS,
            ),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${records.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              children: [
                for (final record in records)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppConstants.spacingS,
                    ),
                    child: _SavedImageThumbnail(
                      record: record,
                      folder: folder,
                      onTap: () => onOpen(record),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Thumbnail for a saved history image, loaded from the save folder
class _SavedImageThumbnail extends StatelessWidget {
  final SavedImageRecord record;
  final String folder;
  final VoidCallback onTap;

  const _SavedImageThumbnail({
    required this.record,
    required this.folder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File('$folder/${record.fileName}');

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: theme.colorScheme.surface,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: theme.disabledColor,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                color: Colors.black.withValues(alpha: 0.55),
                child: Text(
                  record.prompt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
