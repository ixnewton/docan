import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
import '../config/themes.dart';
import '../models/ai_provider.dart';
import '../utils/liquid_glass_effects.dart';

/// Settings form for API keys and configuration
class SettingsForm extends StatefulWidget {
  final Map<AIProvider, String> apiKeys;
  final String ollamaUrl;
  final LiquidGlassTheme theme;
  final Color accentColor;
  final double temperature;
  final int maxTokens;
  final Function(AIProvider, String) onApiKeyChanged;
  final ValueChanged<String> onOllamaUrlChanged;
  final ValueChanged<LiquidGlassTheme> onThemeChanged;
  final ValueChanged<Color> onAccentColorChanged;
  final ValueChanged<double> onTemperatureChanged;
  final ValueChanged<int> onMaxTokensChanged;
  final Function(AIProvider)? onTestConnection;
  final Map<AIProvider, bool>? connectionStatus;

  const SettingsForm({
    super.key,
    required this.apiKeys,
    required this.ollamaUrl,
    required this.theme,
    required this.accentColor,
    required this.temperature,
    required this.maxTokens,
    required this.onApiKeyChanged,
    required this.onOllamaUrlChanged,
    required this.onThemeChanged,
    required this.onAccentColorChanged,
    required this.onTemperatureChanged,
    required this.onMaxTokensChanged,
    this.onTestConnection,
    this.connectionStatus,
  });

  @override
  State<SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<SettingsForm> {
  final Map<AIProvider, TextEditingController> _controllers = {};
  final TextEditingController _ollamaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final provider in AIProvider.values) {
      _controllers[provider] = TextEditingController(
        text: widget.apiKeys[provider] ?? '',
      );
    }
    _ollamaController.text = widget.ollamaUrl;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _ollamaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      children: [
        // API Keys Section
        _buildSection(
          context,
          title: 'API Keys',
          icon: Icons.key,
          children: [
            ...AIProvider.values.where((p) => p.requiresApiKey).map(
                  (provider) => _buildApiKeyField(provider),
                ),
            _buildOllamaUrlField(),
          ],
        ),

        const SizedBox(height: AppConstants.spacingL),

        // Appearance Section
        _buildSection(
          context,
          title: 'Appearance',
          icon: Icons.palette,
          children: [
            _buildThemeSelector(),
            const SizedBox(height: AppConstants.spacingM),
            _buildAccentColorSelector(),
          ],
        ),

        const SizedBox(height: AppConstants.spacingL),

        // AI Parameters Section
        _buildSection(
          context,
          title: 'AI Parameters',
          icon: Icons.tune,
          children: [
            _buildTemperatureSlider(),
            const SizedBox(height: AppConstants.spacingM),
            _buildMaxTokensSlider(),
          ],
        ),

        const SizedBox(height: AppConstants.spacingL),

        // About Section
        _buildSection(
          context,
          title: 'About',
          icon: Icons.info_outline,
          children: [
            _buildAboutSection(),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return LiquidGlassContainer(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.primaryColor),
              const SizedBox(width: AppConstants.spacingS),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          const Divider(height: 1),
          const SizedBox(height: AppConstants.spacingM),
          ...children,
        ],
      ),
    );
  }

  Widget _buildApiKeyField(AIProvider provider) {
    final theme = Theme.of(context);
    final isConnected = widget.connectionStatus?[provider] ?? false;
    final hasKey = _controllers[provider]?.text.isNotEmpty ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                provider.icon,
                size: 18,
                color: provider.color,
              ),
              const SizedBox(width: AppConstants.spacingS),
              Text(
                provider.apiKeyName,
                style: theme.textTheme.labelLarge,
              ),
              const Spacer(),
              if (hasKey)
                Icon(
                  isConnected ? Icons.check_circle : Icons.error_outline,
                  size: 18,
                  color: isConnected ? Colors.green : Colors.orange,
                ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingS),
          Row(
            children: [
              Expanded(
                child: LiquidGlassTextField(
                  controller: _controllers[provider],
                  hintText: 'Enter your ${provider.displayName} API key',
                  obscureText: true,
                  onChanged: (value) => widget.onApiKeyChanged(provider, value),
                ),
              ),
              if (widget.onTestConnection != null) ...[
                const SizedBox(width: AppConstants.spacingS),
                LiquidGlassIconButton(
                  icon: Icons.refresh,
                  tooltip: 'Test Connection',
                  onPressed: () => widget.onTestConnection!(provider),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOllamaUrlField() {
    final theme = Theme.of(context);
    final isConnected = widget.connectionStatus?[AIProvider.ollama] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              AIProvider.ollama.icon,
              size: 18,
              color: AIProvider.ollama.color,
            ),
            const SizedBox(width: AppConstants.spacingS),
            Text(
              'Ollama URL',
              style: theme.textTheme.labelLarge,
            ),
            const Spacer(),
            Icon(
              isConnected ? Icons.check_circle : Icons.error_outline,
              size: 18,
              color: isConnected ? Colors.green : Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingS),
        Row(
          children: [
            Expanded(
              child: LiquidGlassTextField(
                controller: _ollamaController,
                hintText: 'http://localhost:11434',
                onChanged: widget.onOllamaUrlChanged,
              ),
            ),
            if (widget.onTestConnection != null) ...[
              const SizedBox(width: AppConstants.spacingS),
              LiquidGlassIconButton(
                icon: Icons.refresh,
                tooltip: 'Test Connection',
                onPressed: () => widget.onTestConnection!(AIProvider.ollama),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildThemeSelector() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Liquid Glass Style',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: AppConstants.spacingS),
        Wrap(
          spacing: AppConstants.spacingS,
          runSpacing: AppConstants.spacingS,
          children: LiquidGlassTheme.values.map((t) {
            final isSelected = t == widget.theme;
            return GestureDetector(
              onTap: () => widget.onThemeChanged(t),
              child: AnimatedContainer(
                duration: AppConstants.hoverDuration,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingM,
                  vertical: AppConstants.spacingS,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.primaryColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  border: Border.all(
                    color: isSelected
                        ? theme.primaryColor
                        : theme.dividerColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getThemePreviewColor(t),
                        border: Border.all(color: theme.dividerColor),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      t.name[0].toUpperCase() + t.name.substring(1),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getThemePreviewColor(LiquidGlassTheme t) {
    switch (t) {
      case LiquidGlassTheme.clear:
        return Colors.black;
      case LiquidGlassTheme.light:
        return Colors.white;
      case LiquidGlassTheme.dark:
        return const Color(0xFF1C1C1E);
      case LiquidGlassTheme.tinted:
        return widget.accentColor.withValues(alpha: 0.3);
    }
  }

  Widget _buildAccentColorSelector() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accent Color',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: AppConstants.spacingS),
        Wrap(
          spacing: AppConstants.spacingS,
          runSpacing: AppConstants.spacingS,
          children: LiquidGlassColors.accentColors.map((color) {
            final isSelected = color.toARGB32() == widget.accentColor.toARGB32();
            return GestureDetector(
              onTap: () => widget.onAccentColorChanged(color),
              child: AnimatedContainer(
                duration: AppConstants.hoverDuration,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTemperatureSlider() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Temperature',
              style: theme.textTheme.labelLarge,
            ),
            Text(
              widget.temperature.toStringAsFixed(1),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingS),
        Slider(
          value: widget.temperature,
          min: AppConstants.minTemperature,
          max: AppConstants.maxTemperature,
          divisions: 20,
          label: widget.temperature.toStringAsFixed(1),
          onChanged: widget.onTemperatureChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Precise', style: theme.textTheme.labelSmall),
            Text('Creative', style: theme.textTheme.labelSmall),
          ],
        ),
      ],
    );
  }

  Widget _buildMaxTokensSlider() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Max Tokens',
              style: theme.textTheme.labelLarge,
            ),
            Text(
              widget.maxTokens.toString(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingS),
        Slider(
          value: widget.maxTokens.toDouble(),
          min: AppConstants.minMaxTokens.toDouble(),
          max: AppConstants.maxMaxTokens.toDouble(),
          divisions: 31,
          label: widget.maxTokens.toString(),
          onChanged: (value) => widget.onMaxTokensChanged(value.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${AppConstants.minMaxTokens}', style: theme.textTheme.labelSmall),
            Text('${AppConstants.maxMaxTokens}', style: theme.textTheme.labelSmall),
          ],
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Version
        _buildAboutRow(
          context,
          icon: Icons.tag,
          title: 'Version',
          subtitle: AppConstants.appVersion,
        ),
        const SizedBox(height: AppConstants.spacingM),
        
        // GitLab
        _buildAboutRow(
          context,
          icon: Icons.code,
          title: 'Source Code',
          subtitle: 'GitLab Repository',
          onTap: () => _launchUrl('https://gitlab.com/Openlyst/docan'),
        ),
        const SizedBox(height: AppConstants.spacingM),
        
        // Website
        _buildAboutRow(
          context,
          icon: Icons.language,
          title: 'Website',
          subtitle: 'openlyst.onrender.com',
          onTap: () => _launchUrl('https://openlyst.onrender.com/'),
        ),
        const SizedBox(height: AppConstants.spacingM),
        
        const Divider(height: 1),
        const SizedBox(height: AppConstants.spacingM),
        
        // Privacy Policy
        _buildAboutRow(
          context,
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          subtitle: 'Your data stays on your device',
          onTap: () => _showPrivacyDialog(context),
        ),
        const SizedBox(height: AppConstants.spacingM),
        
        // Terms of Service
        _buildAboutRow(
          context,
          icon: Icons.description_outlined,
          title: 'Terms of Service',
          subtitle: 'No data collection',
          onTap: () => _showTosDialog(context),
        ),
        const SizedBox(height: AppConstants.spacingM),
        
        // License
        _buildAboutRow(
          context,
          icon: Icons.gavel,
          title: 'License',
          subtitle: 'GNU General Public License v3.0',
          onTap: () => _showLicenseDialog(context),
        ),
      ],
    );
  }

  Widget _buildAboutRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusS),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingXS),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.primaryColor),
            const SizedBox(width: AppConstants.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: Theme.of(context).primaryColor),
            const SizedBox(width: AppConstants.spacingS),
            const Text('Privacy Policy'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Docan Privacy Policy',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                '🔒 We don\'t collect any data at all',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '🚫 We don\'t track anything',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '💻 Everything is stored locally on your device',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Text(
                'Your API keys, conversations, and settings are stored only on your device. We have no servers that collect or store your data. All AI requests go directly from your device to the respective AI provider (Google, OpenAI, Anthropic, or your local Ollama instance).',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTosDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.description_outlined, color: Theme.of(context).primaryColor),
            const SizedBox(width: AppConstants.spacingS),
            const Text('Terms of Service'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Docan Terms of Service',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                '🔒 We don\'t collect any data at all',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '🚫 We don\'t track anything',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '💻 Everything is local',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Text(
                'By using Docan, you agree that:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '• You are responsible for your own API keys and their usage\n'
                '• You will comply with the terms of service of the AI providers you use (Google, OpenAI, Anthropic)\n'
                '• This app is provided "as is" without warranty of any kind\n'
                '• We are not responsible for any content generated by AI providers',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              SizedBox(height: 16),
              Text(
                'Docan is open source software. You can view and contribute to the source code on GitLab.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLicenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.gavel, color: Theme.of(context).primaryColor),
            const SizedBox(width: AppConstants.spacingS),
            const Text('License'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GNU General Public License v3.0',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                'Docan is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                'This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                'See the GNU General Public License for more details.',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 16),
              Text(
                '📜 Permissions:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                '• Commercial use\n'
                '• Distribution\n'
                '• Modification\n'
                '• Patent use\n'
                '• Private use',
                style: TextStyle(fontSize: 13, color: Colors.green),
              ),
              SizedBox(height: 12),
              Text(
                '⚠️ Conditions:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                '• Disclose source\n'
                '• License and copyright notice\n'
                '• Same license\n'
                '• State changes',
                style: TextStyle(fontSize: 13, color: Colors.orange),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _launchUrl('https://www.gnu.org/licenses/gpl-3.0.en.html'),
            child: const Text('View Full License'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
