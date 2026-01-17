import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/constants.dart';
import '../services/image_generation_service.dart';
import '../utils/liquid_glass_effects.dart';

/// ComfyUI settings panel for configuring generation parameters
class ComfyUISettingsPanel extends StatefulWidget {
  final ComfyUISettings settings;
  final ValueChanged<ComfyUISettings> onSettingsChanged;
  final bool isCompact;

  const ComfyUISettingsPanel({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    this.isCompact = false,
  });

  @override
  State<ComfyUISettingsPanel> createState() => _ComfyUISettingsPanelState();
}

class _ComfyUISettingsPanelState extends State<ComfyUISettingsPanel> {
  late TextEditingController _seedController;
  late TextEditingController _negativePromptController;
  late TextEditingController _widthController;
  late TextEditingController _heightController;

  @override
  void initState() {
    super.initState();
    _seedController = TextEditingController(
      text: widget.settings.seed == -1 ? '' : widget.settings.seed.toString(),
    );
    _negativePromptController = TextEditingController(
      text: widget.settings.negativePrompt,
    );
    _widthController = TextEditingController(
      text: widget.settings.width.toString(),
    );
    _heightController = TextEditingController(
      text: widget.settings.height.toString(),
    );
  }

  @override
  void didUpdateWidget(ComfyUISettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _seedController.text = widget.settings.seed == -1 
          ? '' 
          : widget.settings.seed.toString();
      _negativePromptController.text = widget.settings.negativePrompt;
      _widthController.text = widget.settings.width.toString();
      _heightController.text = widget.settings.height.toString();
    }
  }

  @override
  void dispose() {
    _seedController.dispose();
    _negativePromptController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _updateSettings(ComfyUISettings newSettings) {
    widget.onSettingsChanged(newSettings);
  }

  void _randomizeSeed() {
    final newSeed = Random().nextInt(4294967295);
    _seedController.text = newSeed.toString();
    _updateSettings(widget.settings.copyWith(seed: newSeed));
  }

  void _swapDimensions() {
    final width = widget.settings.width;
    final height = widget.settings.height;
    _widthController.text = height.toString();
    _heightController.text = width.toString();
    _updateSettings(widget.settings.copyWith(width: height, height: width));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (widget.isCompact) {
      return _buildCompactView(theme);
    }
    return _buildFullView(theme);
  }

  Widget _buildFullView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sampler & Scheduler Row
          _buildSectionTitle(theme, 'Sampling'),
          const SizedBox(height: AppConstants.spacingS),
          Row(
            children: [
              Expanded(child: _buildSamplerDropdown(theme)),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(child: _buildSchedulerDropdown(theme)),
            ],
          ),

          const SizedBox(height: AppConstants.spacingL),

          // Steps & CFG Row
          _buildSectionTitle(theme, 'Generation'),
          const SizedBox(height: AppConstants.spacingS),
          Row(
            children: [
              Expanded(child: _buildStepsSlider(theme)),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(child: _buildCFGSlider(theme)),
            ],
          ),

          const SizedBox(height: AppConstants.spacingL),

          // Resolution
          _buildSectionTitle(theme, 'Resolution'),
          const SizedBox(height: AppConstants.spacingS),
          _buildResolutionSection(theme),

          const SizedBox(height: AppConstants.spacingL),

          // Seed
          _buildSectionTitle(theme, 'Seed'),
          const SizedBox(height: AppConstants.spacingS),
          _buildSeedField(theme),

          const SizedBox(height: AppConstants.spacingL),

          // Negative Prompt
          _buildSectionTitle(theme, 'Negative Prompt'),
          const SizedBox(height: AppConstants.spacingS),
          _buildNegativePromptField(theme),
        ],
      ),
    );
  }

  Widget _buildCompactView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sampler
          _buildCompactDropdown(
            theme,
            'Sampler',
            widget.settings.sampler,
            ComfyUISettings.availableSamplers,
            (value) => _updateSettings(widget.settings.copyWith(sampler: value)),
          ),
          const SizedBox(height: AppConstants.spacingM),

          // Scheduler
          _buildCompactDropdown(
            theme,
            'Scheduler',
            widget.settings.scheduler,
            ComfyUISettings.availableSchedulers,
            (value) => _updateSettings(widget.settings.copyWith(scheduler: value)),
          ),
          const SizedBox(height: AppConstants.spacingM),

          // Steps
          _buildCompactSlider(
            theme,
            'Steps',
            widget.settings.steps.toDouble(),
            1,
            150,
            (value) => _updateSettings(widget.settings.copyWith(steps: value.round())),
            isInteger: true,
          ),
          const SizedBox(height: AppConstants.spacingM),

          // CFG Scale
          _buildCompactSlider(
            theme,
            'CFG Scale',
            widget.settings.cfgScale,
            1,
            30,
            (value) => _updateSettings(widget.settings.copyWith(cfgScale: value)),
          ),
          const SizedBox(height: AppConstants.spacingM),

          // Resolution preset
          _buildResolutionPresets(theme),
          const SizedBox(height: AppConstants.spacingM),

          // Width & Height
          Row(
            children: [
              Expanded(
                child: _buildCompactNumberField(
                  theme,
                  'Width',
                  _widthController,
                  (value) {
                    final w = int.tryParse(value) ?? 512;
                    _updateSettings(widget.settings.copyWith(width: w));
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.swap_horiz, size: 20),
                onPressed: _swapDimensions,
                tooltip: 'Swap dimensions',
              ),
              Expanded(
                child: _buildCompactNumberField(
                  theme,
                  'Height',
                  _heightController,
                  (value) {
                    final h = int.tryParse(value) ?? 512;
                    _updateSettings(widget.settings.copyWith(height: h));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),

          // Seed
          _buildCompactSeedField(theme),
          const SizedBox(height: AppConstants.spacingM),

          // Negative Prompt
          _buildCompactTextField(
            theme,
            'Negative Prompt',
            _negativePromptController,
            (value) => _updateSettings(widget.settings.copyWith(negativePrompt: value)),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildSamplerDropdown(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sampler', style: theme.textTheme.labelMedium),
        const SizedBox(height: AppConstants.spacingXS),
        LiquidGlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
          child: DropdownButton<String>(
            value: widget.settings.sampler,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: theme.cardColor,
            items: ComfyUISettings.availableSamplers.map((s) {
              return DropdownMenuItem(value: s, child: Text(s));
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _updateSettings(widget.settings.copyWith(sampler: value));
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSchedulerDropdown(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Scheduler', style: theme.textTheme.labelMedium),
        const SizedBox(height: AppConstants.spacingXS),
        LiquidGlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
          child: DropdownButton<String>(
            value: widget.settings.scheduler,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: theme.cardColor,
            items: ComfyUISettings.availableSchedulers.map((s) {
              return DropdownMenuItem(value: s, child: Text(s));
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _updateSettings(widget.settings.copyWith(scheduler: value));
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStepsSlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Steps', style: theme.textTheme.labelMedium),
            Text(
              widget.settings.steps.toString(),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: widget.settings.steps.toDouble(),
          min: 1,
          max: 150,
          divisions: 149,
          onChanged: (value) {
            _updateSettings(widget.settings.copyWith(steps: value.round()));
          },
        ),
      ],
    );
  }

  Widget _buildCFGSlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('CFG Scale', style: theme.textTheme.labelMedium),
            Text(
              widget.settings.cfgScale.toStringAsFixed(1),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: widget.settings.cfgScale,
          min: 1,
          max: 30,
          divisions: 58,
          onChanged: (value) {
            _updateSettings(widget.settings.copyWith(
              cfgScale: double.parse(value.toStringAsFixed(1)),
            ));
          },
        ),
      ],
    );
  }

  Widget _buildResolutionSection(ThemeData theme) {
    return Column(
      children: [
        // Preset buttons
        _buildResolutionPresets(theme),
        const SizedBox(height: AppConstants.spacingM),
        // Custom resolution
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Width', style: theme.textTheme.labelMedium),
                  const SizedBox(height: AppConstants.spacingXS),
                  LiquidGlassTextField(
                    controller: _widthController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final w = int.tryParse(value) ?? 512;
                      _updateSettings(widget.settings.copyWith(width: w));
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingS),
              child: IconButton(
                icon: const Icon(Icons.swap_horiz),
                onPressed: _swapDimensions,
                tooltip: 'Swap dimensions',
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Height', style: theme.textTheme.labelMedium),
                  const SizedBox(height: AppConstants.spacingXS),
                  LiquidGlassTextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final h = int.tryParse(value) ?? 512;
                      _updateSettings(widget.settings.copyWith(height: h));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResolutionPresets(ThemeData theme) {
    return Wrap(
      spacing: AppConstants.spacingS,
      runSpacing: AppConstants.spacingS,
      children: ComfyUISettings.resolutionPresets.map((preset) {
        final w = preset['width']!;
        final h = preset['height']!;
        final isSelected = widget.settings.width == w && widget.settings.height == h;
        return GestureDetector(
          onTap: () {
            _widthController.text = w.toString();
            _heightController.text = h.toString();
            _updateSettings(widget.settings.copyWith(width: w, height: h));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingS,
              vertical: AppConstants.spacingXS,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.dividerColor,
              ),
            ),
            child: Text(
              '${w}x$h',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.colorScheme.primary : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSeedField(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: LiquidGlassTextField(
            controller: _seedController,
            hintText: 'Random (-1)',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) {
              final seed = value.isEmpty ? -1 : (int.tryParse(value) ?? -1);
              _updateSettings(widget.settings.copyWith(seed: seed));
            },
          ),
        ),
        const SizedBox(width: AppConstants.spacingS),
        LiquidGlassIconButton(
          icon: Icons.casino,
          tooltip: 'Random seed',
          onPressed: _randomizeSeed,
        ),
      ],
    );
  }

  Widget _buildNegativePromptField(ThemeData theme) {
    return LiquidGlassTextField(
      controller: _negativePromptController,
      hintText: 'Things to avoid in the image...',
      maxLines: 3,
      onChanged: (value) {
        _updateSettings(widget.settings.copyWith(negativePrompt: value));
      },
    );
  }

  // Compact view builders
  Widget _buildCompactDropdown(
    ThemeData theme,
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: AppConstants.spacingXS),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingS),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppConstants.radiusS),
            border: Border.all(color: theme.dividerColor),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: theme.cardColor,
            style: theme.textTheme.bodySmall,
            items: items.map((s) {
              return DropdownMenuItem(value: s, child: Text(s));
            }).toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSlider(
    ThemeData theme,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    bool isInteger = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            Text(
              isInteger ? value.round().toString() : value.toStringAsFixed(1),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactNumberField(
    ThemeData theme,
    String label,
    TextEditingController controller,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: AppConstants.spacingXS),
        SizedBox(
          height: 36,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: theme.textTheme.bodySmall,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingS,
                vertical: AppConstants.spacingXS,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusS),
              ),
              isDense: true,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSeedField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Seed', style: theme.textTheme.labelSmall),
        const SizedBox(height: AppConstants.spacingXS),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _seedController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: theme.textTheme.bodySmall,
                  decoration: InputDecoration(
                    hintText: 'Random',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingS,
                      vertical: AppConstants.spacingXS,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final seed = value.isEmpty ? -1 : (int.tryParse(value) ?? -1);
                    _updateSettings(widget.settings.copyWith(seed: seed));
                  },
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacingS),
            SizedBox(
              height: 36,
              width: 36,
              child: IconButton(
                icon: const Icon(Icons.casino, size: 18),
                onPressed: _randomizeSeed,
                tooltip: 'Random seed',
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactTextField(
    ThemeData theme,
    String label,
    TextEditingController controller,
    ValueChanged<String> onChanged, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: AppConstants.spacingXS),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: theme.textTheme.bodySmall,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(AppConstants.spacingS),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
            ),
            isDense: true,
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Bottom sheet for ComfyUI settings (mobile)
class ComfyUISettingsSheet extends StatelessWidget {
  final ComfyUISettings settings;
  final ValueChanged<ComfyUISettings> onSettingsChanged;

  const ComfyUISettingsSheet({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
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
            child: Row(
              children: [
                const Icon(Icons.tune, size: 20),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'ComfyUI Settings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Settings
          Flexible(
            child: ComfyUISettingsPanel(
              settings: settings,
              onSettingsChanged: onSettingsChanged,
              isCompact: true,
            ),
          ),
        ],
      ),
    );
  }
}
