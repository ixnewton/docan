import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/constants.dart';
import '../../components/comfyui_settings_panel.dart';
import '../../services/clipboard_service.dart';
import '../../services/image_generation_service.dart';
import '../../utils/liquid_glass_effects.dart';

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

  @override
  void initState() {
    super.initState();
    _loadConfiguredProviders();
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

  @override
  void dispose() {
    _promptController.dispose();
    _promptFocusNode.dispose();
    super.dispose();
  }

  Future<void> _generateImage() async {
    final service = context.read<ImageGenerationService>();
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    final image = await service.generateImage(prompt, size: _selectedSize);
    if (image != null && mounted) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _saveImage(GeneratedImage image) async {
    try {
      final directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final fileName =
          'docan_image_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(image.imageData);

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
          body: Row(
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
                            _buildComfyUISettingsPanel(context, service, isDark),
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
                LiquidGlassIconButton(
                  icon: Icons.close,
                  size: 32,
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
                Icon(Icons.image, color: theme.primaryColor),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'Generated Images',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Image gallery
          Expanded(
            child: service.generatedImages.isEmpty
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
                : ListView.builder(
                    padding: const EdgeInsets.all(AppConstants.spacingS),
                    itemCount: service.generatedImages.length,
                    itemBuilder: (context, index) {
                      final image = service.generatedImages[index];
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
                            });
                          },
                          onDelete: () {
                            service.deleteImage(image.id);
                            if (_selectedImage?.id == image.id) {
                              setState(() {
                                _selectedImage =
                                    service.generatedImages.isNotEmpty
                                    ? service.generatedImages.first
                                    : null;
                              });
                            }
                          },
                        ),
                      );
                    },
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
          // Provider selector
          _ImageProviderSelector(
            selectedProvider: service.selectedProvider,
            selectedModel: service.selectedModel,
            onProviderChanged: service.setProvider,
            onModelChanged: service.setModel,
            configuredProviders: _configuredProviders,
            fetchModels: service.getAvailableModels,
          ),

          const Spacer(),

          // ComfyUI Settings toggle (only when ComfyUI is selected)
          if (service.selectedProvider == ImageGenProvider.comfyui) ...[
            LiquidGlassIconButton(
              icon: _showComfyUISettings ? Icons.tune : Icons.tune_outlined,
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
            LiquidGlassIconButton(
              icon: Icons.save_alt,
              tooltip: 'Save Image',
              onPressed: () => _saveImage(_selectedImage!),
            ),
            const SizedBox(width: AppConstants.spacingS),
            LiquidGlassIconButton(
              icon: Icons.copy,
              tooltip: 'Copy Prompt',
              onPressed: () => _copyImageToClipboard(_selectedImage!),
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
        child: LiquidGlassContainer(
          padding: const EdgeInsets.all(AppConstants.spacingL),
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
              LiquidGlassButton(
                onPressed: service.clearError,
                child: const Text(
                  'Dismiss',
                  style: TextStyle(color: Colors.white),
                ),
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
            child: LiquidGlassTextField(
              controller: _promptController,
              focusNode: _promptFocusNode,
              hintText: hasApiKey
                  ? 'Describe the image you want to create...'
                  : 'Add API key in settings to generate images',
              enabled: hasApiKey && !service.isGenerating,
              maxLines: 3,
              minLines: 1,
              onSubmitted: (_) => _generateImage(),
            ),
          ),
          const SizedBox(width: AppConstants.spacingM),
          LiquidGlassButton(
            onPressed: hasApiKey && !service.isGenerating
                ? _generateImage
                : null,
            isLoading: service.isGenerating,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                SizedBox(width: AppConstants.spacingS),
                Text('Generate', style: TextStyle(color: Colors.white)),
              ],
            ),
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
              child: LiquidGlassContainer(
                padding: const EdgeInsets.all(AppConstants.spacingS),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  child: Image.memory(image.imageData, fit: BoxFit.contain),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // Info
          LiquidGlassContainer(
            padding: const EdgeInsets.all(AppConstants.spacingM),
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

/// Image provider selector
class _ImageProviderSelector extends StatefulWidget {
  final ImageGenProvider selectedProvider;
  final String selectedModel;
  final ValueChanged<ImageGenProvider> onProviderChanged;
  final ValueChanged<String> onModelChanged;
  final Map<ImageGenProvider, bool> configuredProviders;
  final Future<List<String>> Function(ImageGenProvider) fetchModels;

  const _ImageProviderSelector({
    required this.selectedProvider,
    required this.selectedModel,
    required this.onProviderChanged,
    required this.onModelChanged,
    required this.configuredProviders,
    required this.fetchModels,
  });

  @override
  State<_ImageProviderSelector> createState() => _ImageProviderSelectorState();
}

class _ImageProviderSelectorState extends State<_ImageProviderSelector> {
  List<String>? _cachedModels;
  ImageGenProvider? _cachedProvider;
  final bool _isLoadingModels = false;

  Future<List<String>> _getModels() async {
    // Return cached if same provider
    if (_cachedModels != null && _cachedProvider == widget.selectedProvider) {
      return _cachedModels!;
    }

    final models = await widget.fetchModels(widget.selectedProvider);
    _cachedModels = models;
    _cachedProvider = widget.selectedProvider;
    return models;
  }

  void _clearCache() {
    _cachedModels = null;
    _cachedProvider = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Provider dropdown
        PopupMenuButton<ImageGenProvider>(
          initialValue: widget.selectedProvider,
          onSelected: (provider) {
            _clearCache();
            widget.onProviderChanged(provider);
          },
          itemBuilder: (context) {
            return ImageGenProvider.values.map((provider) {
              final isConfigured = widget.configuredProviders[provider] ?? false;
              return PopupMenuItem<ImageGenProvider>(
                value: provider,
                enabled: isConfigured,
                child: Row(
                  children: [
                    Icon(
                      provider.icon,
                      size: 18,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(provider.displayName),
                    if (!isConfigured) ...[
                      const Spacer(),
                      Icon(
                        Icons.key_off,
                        size: 16,
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList();
          },
          child: LiquidGlassContainer(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingM,
              vertical: AppConstants.spacingS,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.selectedProvider.icon,
                  size: 18,
                ),
                const SizedBox(width: AppConstants.spacingS),
                Text(widget.selectedProvider.displayName),
                const SizedBox(width: AppConstants.spacingS),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ),

        const SizedBox(width: AppConstants.spacingS),

        // Model dropdown - loads models asynchronously
        _ModelDropdownButton(
          selectedModel: widget.selectedModel,
          onModelChanged: widget.onModelChanged,
          fetchModels: _getModels,
          isLoading: _isLoadingModels,
        ),
      ],
    );
  }
}

/// Async model dropdown button
class _ModelDropdownButton extends StatefulWidget {
  final String selectedModel;
  final ValueChanged<String> onModelChanged;
  final Future<List<String>> Function() fetchModels;
  final bool isLoading;

  const _ModelDropdownButton({
    required this.selectedModel,
    required this.onModelChanged,
    required this.fetchModels,
    required this.isLoading,
  });

  @override
  State<_ModelDropdownButton> createState() => _ModelDropdownButtonState();
}

class _ModelDropdownButtonState extends State<_ModelDropdownButton> {
  List<String>? _models;
  bool _isLoading = false;

  Future<void> _loadModels() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final models = await widget.fetchModels();
      if (mounted) {
        setState(() {
          _models = models;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showModelMenu(BuildContext context) async {
    if (_models == null || _models!.isEmpty) {
      await _loadModels();
    }

    if (!mounted || _models == null || _models!.isEmpty) return;

    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(
      Offset(0, button.size.height),
      ancestor: overlay,
    );

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + 4,
        offset.dx + button.size.width,
        offset.dy + 4,
      ),
      items: _models!.map((model) {
        return PopupMenuItem<String>(value: model, child: Text(model));
      }).toList(),
    );

    if (selected != null) {
      widget.onModelChanged(selected);
    }
  }

  @override
  void didUpdateWidget(_ModelDropdownButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear cache if the fetch function changes (provider changed)
    if (oldWidget.fetchModels != widget.fetchModels) {
      _models = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _showModelMenu(context),
      child: LiquidGlassContainer(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingM,
          vertical: AppConstants.spacingS,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.textTheme.bodySmall?.color,
                ),
              )
            else
              Text(widget.selectedModel, style: theme.textTheme.bodySmall),
            const SizedBox(width: AppConstants.spacingS),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Size selector
class _SizeSelector extends StatelessWidget {
  final ImageSize selectedSize;
  final ValueChanged<ImageSize> onChanged;

  const _SizeSelector({required this.selectedSize, required this.onChanged});

  @override
  Widget build(BuildContext context) {
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
      child: LiquidGlassContainer(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingM,
          vertical: AppConstants.spacingS,
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
