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

/// Mobile image generation screen
class MobileImageScreen extends StatefulWidget {
  const MobileImageScreen({super.key});

  @override
  State<MobileImageScreen> createState() => _MobileImageScreenState();
}

class _MobileImageScreenState extends State<MobileImageScreen> {
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocusNode = FocusNode();
  Map<ImageGenProvider, bool> _configuredProviders = {};
  ImageSize _selectedSize = ImageSize.large;
  GeneratedImage? _selectedImage;

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

    // Unfocus keyboard
    _promptFocusNode.unfocus();

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
            content: Text('Image saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyPrompt(GeneratedImage image) async {
    try {
      await ClipboardService.setText(image.revisedPrompt ?? image.prompt);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prompt copied'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Clipboard failed
    }
  }

  void _showGallery() {
    final service = context.read<ImageGenerationService>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GalleryBottomSheet(
        images: service.generatedImages,
        selectedImage: _selectedImage,
        onSelect: (image) {
          setState(() {
            _selectedImage = image;
          });
          Navigator.pop(context);
        },
        onDelete: (image) {
          service.deleteImage(image.id);
          if (_selectedImage?.id == image.id) {
            setState(() {
              _selectedImage = service.generatedImages.isNotEmpty
                  ? service.generatedImages.first
                  : null;
            });
          }
        },
        onClear: () {
          service.clearImages();
          setState(() {
            _selectedImage = null;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showSettings() {
    final service = context.read<ImageGenerationService>();
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SettingsBottomSheet(
        parentContext: parentContext,
        selectedProvider: service.selectedProvider,
        selectedModel: service.selectedModel,
        selectedSize: _selectedSize,
        configuredProviders: _configuredProviders,
        comfyUISettings: service.comfyUISettings,
        onProviderChanged: (provider) {
          service.setProvider(provider);
        },
        onModelChanged: (model) {
          service.setModel(model);
        },
        onSizeChanged: (size) {
          setState(() {
            _selectedSize = size;
          });
        },
        onComfyUISettingsChanged: service.updateComfyUISettings,
        fetchModels: service.getAvailableModels,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<ImageGenerationService>(
      builder: (context, service, child) {
        final hasApiKey =
            _configuredProviders[service.selectedProvider] ?? false;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // Nav bar
                _buildNavBar(context, service),

                // Main content
                Expanded(child: _buildContent(context, service)),

                // Prompt input
                _buildPromptInput(context, service, hasApiKey),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavBar(BuildContext context, ImageGenerationService service) {
    final theme = Theme.of(context);

    return LiquidGlassNavBar(
      child: Row(
        children: [
          // Back button
          LiquidGlassIconButton(
            icon: Icons.arrow_back,
            onPressed: () => Navigator.pop(context),
          ),

          const SizedBox(width: AppConstants.spacingS),

          // Title
          Text(
            'Image Creator',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const Spacer(),

          // Gallery button
          if (service.generatedImages.isNotEmpty)
            Stack(
              children: [
                LiquidGlassIconButton(
                  icon: Icons.photo_library,
                  onPressed: _showGallery,
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${service.generatedImages.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(width: AppConstants.spacingXS),

          // Settings button
          LiquidGlassIconButton(icon: Icons.tune, onPressed: _showSettings),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ImageGenerationService service) {
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
            Text('Creating your image...', style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'This may take a moment',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (service.error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Center(
          child: LiquidGlassContainer(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: AppConstants.spacingM),
                Text(
                  'Something went wrong',
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
                    'Try Again',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_selectedImage == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingL),
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
                'Create Amazing Images',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Text(
                'Describe what you want to see and AI will bring it to life',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.6,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spacingL),
              // Example prompts
              _ExamplePrompts(
                onSelect: (prompt) {
                  _promptController.text = prompt;
                  _promptFocusNode.requestFocus();
                },
              ),
            ],
          ),
        ),
      );
    }

    return _MobileImageViewer(
      image: _selectedImage!,
      onSave: () => _saveImage(_selectedImage!),
      onCopyPrompt: () => _copyPrompt(_selectedImage!),
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
            : Colors.white.withValues(alpha: 0.7),
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: LiquidGlassTextField(
                  controller: _promptController,
                  focusNode: _promptFocusNode,
                  hintText: hasApiKey
                      ? 'Describe your image...'
                      : 'Add API key in settings first',
                  enabled: hasApiKey && !service.isGenerating,
                  maxLines: 4,
                  minLines: 1,
                  onSubmitted: (_) => _generateImage(),
                ),
              ),
              const SizedBox(width: AppConstants.spacingS),
              LiquidGlassButton(
                onPressed: hasApiKey && !service.isGenerating
                    ? _generateImage
                    : null,
                isLoading: service.isGenerating,
                padding: const EdgeInsets.all(AppConstants.spacingM),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Example prompts widget
class _ExamplePrompts extends StatelessWidget {
  final ValueChanged<String> onSelect;

  const _ExamplePrompts({required this.onSelect});

  static const _prompts = [
    'A serene Japanese garden with cherry blossoms',
    'Futuristic cityscape at sunset',
    'Cute robot reading a book in a cozy library',
    'Abstract art with vibrant colors',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Try these prompts:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppConstants.spacingS),
        Wrap(
          spacing: AppConstants.spacingS,
          runSpacing: AppConstants.spacingS,
          children: _prompts.map((prompt) {
            return GestureDetector(
              onTap: () => onSelect(prompt),
              child: LiquidGlassContainer(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingM,
                  vertical: AppConstants.spacingS,
                ),
                child: Text(prompt, style: theme.textTheme.bodySmall),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Mobile image viewer
class _MobileImageViewer extends StatelessWidget {
  final GeneratedImage image;
  final VoidCallback onSave;
  final VoidCallback onCopyPrompt;

  const _MobileImageViewer({
    required this.image,
    required this.onSave,
    required this.onCopyPrompt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        children: [
          // Image
          LiquidGlassContainer(
            padding: const EdgeInsets.all(AppConstants.spacingS),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
              child: Image.memory(image.imageData, fit: BoxFit.contain),
            ),
          ),

          const SizedBox(height: AppConstants.spacingM),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: LiquidGlassButton(
                  onPressed: onSave,
                  backgroundColor: theme.primaryColor,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_alt, color: Colors.white, size: 20),
                      SizedBox(width: AppConstants.spacingS),
                      Text('Save', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: LiquidGlassButton(
                  onPressed: onCopyPrompt,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.copy, color: Colors.white, size: 20),
                      SizedBox(width: AppConstants.spacingS),
                      Text(
                        'Copy Prompt',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.spacingM),

          // Info card
          LiquidGlassContainer(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      image.provider.icon,
                      size: 16,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Expanded(
                      child: Text(
                        '${image.provider.displayName} - ${image.model}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  image.revisedPrompt ?? image.prompt,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gallery bottom sheet
class _GalleryBottomSheet extends StatelessWidget {
  final List<GeneratedImage> images;
  final GeneratedImage? selectedImage;
  final ValueChanged<GeneratedImage> onSelect;
  final ValueChanged<GeneratedImage> onDelete;
  final VoidCallback onClear;

  const _GalleryBottomSheet({
    required this.images,
    required this.selectedImage,
    required this.onSelect,
    required this.onDelete,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusL),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: AppConstants.spacingS),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Row(
              children: [
                Text(
                  'Gallery',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onClear,
                  child: const Text(
                    'Clear All',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppConstants.spacingM,
                crossAxisSpacing: AppConstants.spacingM,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final image = images[index];
                final isSelected = selectedImage?.id == image.id;

                return GestureDetector(
                  onTap: () => onSelect(image),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusS,
                          ),
                          border: Border.all(
                            color: isSelected
                                ? theme.primaryColor
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusS - 2,
                          ),
                          child: Image.memory(
                            image.imageData,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => onDelete(image),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings bottom sheet
class _SettingsBottomSheet extends StatefulWidget {
  final BuildContext parentContext;
  final ImageGenProvider selectedProvider;
  final String selectedModel;
  final ImageSize selectedSize;
  final Map<ImageGenProvider, bool> configuredProviders;
  final ComfyUISettings comfyUISettings;
  final ValueChanged<ImageGenProvider> onProviderChanged;
  final ValueChanged<String> onModelChanged;
  final ValueChanged<ImageSize> onSizeChanged;
  final ValueChanged<ComfyUISettings> onComfyUISettingsChanged;
  final Future<List<String>> Function(ImageGenProvider) fetchModels;

  const _SettingsBottomSheet({
    required this.parentContext,
    required this.selectedProvider,
    required this.selectedModel,
    required this.selectedSize,
    required this.configuredProviders,
    required this.comfyUISettings,
    required this.onProviderChanged,
    required this.onModelChanged,
    required this.onSizeChanged,
    required this.onComfyUISettingsChanged,
    required this.fetchModels,
  });

  @override
  State<_SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends State<_SettingsBottomSheet> {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isComfyUI = widget.selectedProvider == ImageGenProvider.comfyui;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusL),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: AppConstants.spacingS),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Text(
              'Settings',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const Divider(height: 1),

          // Provider
          ListTile(
            leading: Icon(widget.selectedProvider.icon),
            title: const Text('Provider'),
            subtitle: Text(widget.selectedProvider.displayName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context);
              _showProviderPicker(widget.parentContext);
            },
          ),

          // Model
          ListTile(
            leading: const Icon(Icons.smart_toy),
            title: const Text('Model'),
            subtitle: Text(widget.selectedModel),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(context);
              _showModelPicker(widget.parentContext);
            },
          ),

          // Size (hide when ComfyUI is selected - it has its own resolution settings)
          if (!isComfyUI)
            ListTile(
              leading: const Icon(Icons.aspect_ratio),
              title: const Text('Image Size'),
              subtitle: Text(widget.selectedSize.displayName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _showSizePicker(widget.parentContext);
              },
            ),

          // ComfyUI Settings (only when ComfyUI is selected)
          if (isComfyUI)
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('ComfyUI Settings'),
              subtitle: Text(
                '${widget.comfyUISettings.width}x${widget.comfyUISettings.height}, '
                '${widget.comfyUISettings.steps} steps, '
                'CFG ${widget.comfyUISettings.cfgScale}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _showComfyUISettings(widget.parentContext);
              },
            ),

          const SizedBox(height: AppConstants.spacingL),
        ],
      ),
    );
  }

  void _showComfyUISettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ComfyUISettingsSheet(
        settings: widget.comfyUISettings,
        onSettingsChanged: widget.onComfyUISettingsChanged,
      ),
    );
  }

  void _showProviderPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PickerSheet<ImageGenProvider>(
        title: 'Select Provider',
        items: ImageGenProvider.values,
        selectedItem: widget.selectedProvider,
        itemBuilder: (provider) => ListTile(
          leading: Icon(
            provider.icon,
          ),
          title: Text(provider.displayName),
          subtitle: Text(provider.description),
          trailing: widget.selectedProvider == provider
              ? Icon(Icons.check, color: Theme.of(context).primaryColor)
              : null,
          enabled: widget.configuredProviders[provider] ?? false,
        ),
        onSelect: widget.onProviderChanged,
      ),
    );
  }

  void _showModelPicker(BuildContext context) async {
    // Fetch models from API
    final models = await widget.fetchModels(widget.selectedProvider);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PickerSheet<String>(
        title: 'Select Model',
        items: models,
        selectedItem: widget.selectedModel,
        itemBuilder: (model) => ListTile(
          title: Text(model),
          trailing: widget.selectedModel == model
              ? Icon(Icons.check, color: Theme.of(context).primaryColor)
              : null,
        ),
        onSelect: widget.onModelChanged,
      ),
    );
  }

  void _showSizePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PickerSheet<ImageSize>(
        title: 'Select Size',
        items: ImageSize.values,
        selectedItem: widget.selectedSize,
        itemBuilder: (size) => ListTile(
          title: Text(size.displayName),
          trailing: widget.selectedSize == size
              ? Icon(Icons.check, color: Theme.of(context).primaryColor)
              : null,
        ),
        onSelect: widget.onSizeChanged,
      ),
    );
  }
}

/// Generic picker sheet
class _PickerSheet<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final T selectedItem;
  final Widget Function(T) itemBuilder;
  final ValueChanged<T> onSelect;

  const _PickerSheet({
    required this.title,
    required this.items,
    required this.selectedItem,
    required this.itemBuilder,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusL),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: AppConstants.spacingS),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const Divider(height: 1),

          // Items
          ...items.map(
            (item) => GestureDetector(
              onTap: () {
                onSelect(item);
                Navigator.pop(context);
              },
              child: itemBuilder(item),
            ),
          ),

          const SizedBox(height: AppConstants.spacingL),
        ],
      ),
    );
  }
}
