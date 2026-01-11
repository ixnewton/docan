import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../models/playbook.dart';
import '../../services/playbook_service.dart';
import '../../utils/liquid_glass_effects.dart';

/// Desktop screen for managing playbooks
class DesktopPlaybooksScreen extends StatefulWidget {
  const DesktopPlaybooksScreen({super.key});

  @override
  State<DesktopPlaybooksScreen> createState() => _DesktopPlaybooksScreenState();
}

class _DesktopPlaybooksScreenState extends State<DesktopPlaybooksScreen> {
  Playbook? _selectedPlaybook;
  bool _showEditor = false;
  final _yamlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaybookService>().initialize();
    });
  }

  @override
  void dispose() {
    _yamlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.watch<PlaybookService>();

    return Scaffold(
      body: Row(
        children: [
          // Sidebar - Playbook list
          SizedBox(
            width: 320,
            child: _PlaybookSidebar(
              playbooks: service.playbooks,
              selectedPlaybook: _selectedPlaybook,
              onSelect: (playbook) {
                setState(() {
                  _selectedPlaybook = playbook;
                  _showEditor = false;
                });
              },
              onImport: _importPlaybook,
              onNewPlaybook: _createNewPlaybook,
            ),
          ),

          // Divider
          Container(width: 1, color: theme.dividerColor.withValues(alpha: 0.2)),

          // Main content
          Expanded(
            child: _selectedPlaybook != null
                ? _showEditor
                      ? _PlaybookEditor(
                          playbook: _selectedPlaybook!,
                          controller: _yamlController,
                          onSave: _savePlaybook,
                          onCancel: () {
                            setState(() {
                              _showEditor = false;
                            });
                          },
                        )
                      : _PlaybookDetail(
                          playbook: _selectedPlaybook!,
                          onEdit: () {
                            _yamlController.text =
                                _selectedPlaybook!.sourceYaml ??
                                _selectedPlaybook!.toYaml();
                            setState(() {
                              _showEditor = true;
                            });
                          },
                          onDelete: () => _deletePlaybook(_selectedPlaybook!),
                          onExport: () => _exportPlaybook(_selectedPlaybook!),
                          onToggleEnabled: (enabled) {
                            service.setEnabled(_selectedPlaybook!.id, enabled);
                          },
                          onConfigure: () =>
                              _showConfigDialog(_selectedPlaybook!),
                        )
                : _EmptyState(
                    onImport: _importPlaybook,
                    onNew: _createNewPlaybook,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _importPlaybook() async {
    try {
      final service = context.read<PlaybookService>();
      final playbook = await service.importFromFile();
      if (playbook != null && mounted) {
        setState(() {
          _selectedPlaybook = playbook;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Imported "${playbook.name}"')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to import: $e')));
      }
    }
  }

  void _createNewPlaybook() {
    _yamlController.text = _getTemplateYaml();
    setState(() {
      _selectedPlaybook = null;
      _showEditor = true;
    });
  }

  Future<void> _savePlaybook() async {
    try {
      final service = context.read<PlaybookService>();
      final playbook = await service.importFromYaml(_yamlController.text);
      if (mounted) {
        setState(() {
          _selectedPlaybook = playbook;
          _showEditor = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved "${playbook.name}"')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  Future<void> _deletePlaybook(Playbook playbook) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playbook'),
        content: Text('Are you sure you want to delete "${playbook.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<PlaybookService>().removePlaybook(playbook.id);
      setState(() {
        _selectedPlaybook = null;
      });
    }
  }

  Future<void> _exportPlaybook(Playbook playbook) async {
    try {
      await context.read<PlaybookService>().exportToFile(playbook);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exported "${playbook.name}"')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export: $e')));
      }
    }
  }

  Future<void> _showConfigDialog(Playbook playbook) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ConfigDialog(playbook: playbook),
    );

    if (result != null && mounted) {
      await context.read<PlaybookService>().updateConfig(playbook.id, result);
    }
  }

  String _getTemplateYaml() {
    return '''name: My Playbook
version: 1.0.0
description: A custom playbook for Docan
author: Your Name
playbookVersion: 1

platforms:
  - android
  - ios
  - linux
  - macos
  - windows
  - web

config:
  apiKey:
    type: string
    required: true
    description: API key for the service
    secret: true

triggers:
  - pattern: "my trigger|keyword"
    description: When to activate this playbook
    priority: 0

actions:
  myAction:
    description: Does something useful
    parameters:
      query:
        type: string
        required: true
        description: The search query
    steps:
      - type: http
        method: GET
        url: "https://api.example.com/search"
        params:
          q: "{{params.query}}"
          key: "{{config.apiKey}}"
        response:
          store: searchResults
      - type: returnData
        data:
          results: "{{searchResults}}"
    returns:
      type: object
      description: Search results
''';
  }
}

/// Sidebar showing list of playbooks
class _PlaybookSidebar extends StatelessWidget {
  final List<Playbook> playbooks;
  final Playbook? selectedPlaybook;
  final ValueChanged<Playbook> onSelect;
  final VoidCallback onImport;
  final VoidCallback onNewPlaybook;

  const _PlaybookSidebar({
    required this.playbooks,
    this.selectedPlaybook,
    required this.onSelect,
    required this.onImport,
    required this.onNewPlaybook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: isDark
          ? Colors.black.withValues(alpha: 0.3)
          : Colors.white.withValues(alpha: 0.5),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Icon(Icons.auto_stories, color: theme.colorScheme.primary),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'Playbooks',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'New Playbook',
                  onPressed: onNewPlaybook,
                ),
                IconButton(
                  icon: const Icon(Icons.file_upload, size: 20),
                  tooltip: 'Import',
                  onPressed: onImport,
                ),
              ],
            ),
          ),

          // Playbook list
          Expanded(
            child: playbooks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_stories_outlined,
                          size: 48,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingM),
                        Text(
                          'No playbooks yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppConstants.spacingS),
                    itemCount: playbooks.length,
                    itemBuilder: (context, index) {
                      final playbook = playbooks[index];
                      final isSelected = selectedPlaybook?.id == playbook.id;

                      return _PlaybookTile(
                        playbook: playbook,
                        isSelected: isSelected,
                        onTap: () => onSelect(playbook),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Tile for displaying a playbook in the list
class _PlaybookTile extends StatelessWidget {
  final Playbook playbook;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlaybookTile({
    required this.playbook,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingXS),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: playbook.enabled
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : theme.disabledColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getIcon(playbook),
                    size: 20,
                    color: playbook.enabled
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playbook.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: playbook.enabled ? null : theme.disabledColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (playbook.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          playbook.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(
                              alpha: playbook.enabled ? 0.7 : 0.4,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Status indicators
                if (!playbook.isConfigured)
                  Tooltip(
                    message: 'Configuration required',
                    child: Icon(
                      Icons.warning_amber,
                      size: 16,
                      color: Colors.orange.shade400,
                    ),
                  ),
                if (!playbook.isSupported)
                  Tooltip(
                    message: 'Not supported on this platform',
                    child: Icon(
                      Icons.block,
                      size: 16,
                      color: Colors.red.shade400,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon(Playbook playbook) {
    // Try to match icon from playbook or infer from name
    final name = playbook.name.toLowerCase();
    if (name.contains('youtube')) return Icons.play_circle_outline;
    if (name.contains('weather')) return Icons.cloud_outlined;
    if (name.contains('music')) return Icons.music_note;
    if (name.contains('news')) return Icons.newspaper;
    if (name.contains('github')) return Icons.code;
    if (name.contains('search')) return Icons.search;
    if (name.contains('email') || name.contains('mail')) {
      return Icons.email_outlined;
    }
    return Icons.extension;
  }
}

/// Detail view for a selected playbook
class _PlaybookDetail extends StatelessWidget {
  final Playbook playbook;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onConfigure;

  const _PlaybookDetail({
    required this.playbook,
    required this.onEdit,
    required this.onDelete,
    required this.onExport,
    required this.onToggleEnabled,
    required this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playbook.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingXS),
                    Row(
                      children: [
                        _InfoChip(
                          icon: Icons.tag,
                          label: 'v${playbook.version}',
                        ),
                        if (playbook.author != null) ...[
                          const SizedBox(width: AppConstants.spacingS),
                          _InfoChip(
                            icon: Icons.person_outline,
                            label: playbook.author!,
                          ),
                        ],
                        const SizedBox(width: AppConstants.spacingS),
                        _InfoChip(
                          icon: Icons.api,
                          label: 'SDK v${playbook.playbookVersion}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              Row(
                children: [
                  Switch(value: playbook.enabled, onChanged: onToggleEnabled),
                  const SizedBox(width: AppConstants.spacingS),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: 'Configure',
                    onPressed: playbook.config.isNotEmpty ? onConfigure : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit YAML',
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_download),
                    tooltip: 'Export',
                    onPressed: onExport,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),

          if (playbook.description != null) ...[
            const SizedBox(height: AppConstants.spacingM),
            Text(playbook.description!, style: theme.textTheme.bodyLarge),
          ],

          // Configuration warning
          if (!playbook.isConfigured) ...[
            const SizedBox(height: AppConstants.spacingM),
            LiquidGlassContainer(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade400),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configuration Required',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Missing: ${playbook.missingConfig.map((c) => c.name).join(", ")}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  LiquidGlassButton(
                    onPressed: onConfigure,
                    child: const Text('Configure'),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppConstants.spacingL),

          // Platforms
          _Section(
            title: 'Supported Platforms',
            child: Wrap(
              spacing: AppConstants.spacingS,
              runSpacing: AppConstants.spacingS,
              children: playbook.platforms.map((p) {
                return _InfoChip(icon: _getPlatformIcon(p), label: p.name);
              }).toList(),
            ),
          ),

          const SizedBox(height: AppConstants.spacingL),

          // Triggers
          if (playbook.triggers.isNotEmpty) ...[
            _Section(
              title: 'Triggers',
              child: Column(
                children: playbook.triggers.map((trigger) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppConstants.spacingS,
                    ),
                    child: LiquidGlassContainer(
                      padding: const EdgeInsets.all(AppConstants.spacingM),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt, size: 20),
                          const SizedBox(width: AppConstants.spacingM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trigger.pattern,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                if (trigger.description != null)
                                  Text(
                                    trigger.description!,
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          _InfoChip(
                            icon: Icons.priority_high,
                            label: 'Priority ${trigger.priority}',
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
          ],

          // Actions
          _Section(
            title: 'Actions',
            child: Column(
              children: playbook.actions.map((action) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppConstants.spacingS),
                  child: _ActionCard(action: action),
                );
              }).toList(),
            ),
          ),

          // Config fields
          if (playbook.config.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacingL),
            _Section(
              title: 'Configuration Fields',
              child: Column(
                children: playbook.config.map((field) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppConstants.spacingS,
                    ),
                    child: LiquidGlassContainer(
                      padding: const EdgeInsets.all(AppConstants.spacingM),
                      child: Row(
                        children: [
                          Icon(
                            field.secret ? Icons.key : Icons.settings,
                            size: 20,
                          ),
                          const SizedBox(width: AppConstants.spacingM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      field.name,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    if (field.required) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '*',
                                        style: TextStyle(
                                          color: Colors.red.shade400,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (field.description != null)
                                  Text(
                                    field.description!,
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          _InfoChip(
                            icon: Icons.data_object,
                            label: field.type.name,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getPlatformIcon(PlaybookPlatform platform) {
    switch (platform) {
      case PlaybookPlatform.android:
        return Icons.android;
      case PlaybookPlatform.ios:
        return Icons.phone_iphone;
      case PlaybookPlatform.linux:
        return Icons.computer;
      case PlaybookPlatform.macos:
        return Icons.desktop_mac;
      case PlaybookPlatform.windows:
        return Icons.desktop_windows;
      case PlaybookPlatform.web:
        return Icons.language;
    }
  }
}

/// Card for displaying an action
class _ActionCard extends StatelessWidget {
  final PlaybookAction action;

  const _ActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LiquidGlassContainer(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_arrow, size: 20),
              const SizedBox(width: AppConstants.spacingS),
              Text(
                action.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (action.description != null) ...[
            const SizedBox(height: AppConstants.spacingXS),
            Text(action.description!, style: theme.textTheme.bodySmall),
          ],
          if (action.parameters.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Parameters:',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingXS),
            Wrap(
              spacing: AppConstants.spacingS,
              runSpacing: AppConstants.spacingXS,
              children: action.parameters.map((param) {
                return _InfoChip(
                  icon: param.required ? Icons.star : Icons.circle_outlined,
                  label: '${param.name}: ${param.type}',
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: AppConstants.spacingS),
          Text(
            '${action.steps.length} step${action.steps.length == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header with title
class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: AppConstants.spacingS),
        child,
      ],
    );
  }
}

/// Small info chip
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingS,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// YAML editor for playbooks
class _PlaybookEditor extends StatelessWidget {
  final Playbook? playbook;
  final TextEditingController controller;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _PlaybookEditor({
    this.playbook,
    required this.controller,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                playbook != null ? 'Edit Playbook' : 'New Playbook',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
              const SizedBox(width: AppConstants.spacingS),
              FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save'),
              ),
            ],
          ),
        ),

        // Editor
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                ),
                hintText: 'Enter playbook YAML...',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Configuration dialog
class _ConfigDialog extends StatefulWidget {
  final Playbook playbook;

  const _ConfigDialog({required this.playbook});

  @override
  State<_ConfigDialog> createState() => _ConfigDialogState();
}

class _ConfigDialogState extends State<_ConfigDialog> {
  late Map<String, dynamic> _config;
  final _controllers = <String, TextEditingController>{};
  final _obscured = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _config = Map.from(widget.playbook.userConfig);
    for (final field in widget.playbook.config) {
      _controllers[field.name] = TextEditingController(
        text:
            _config[field.name]?.toString() ??
            field.defaultValue?.toString() ??
            '',
      );
      _obscured[field.name] = field.secret;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasConfig = widget.playbook.config.isNotEmpty;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.settings),
          const SizedBox(width: AppConstants.spacingS),
          Text('Configure ${widget.playbook.name}'),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: hasConfig
            ? SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter the configuration values for this playbook.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingL),
                    ...widget.playbook.config.map(
                      (field) => _buildField(field),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 48,
                    color: Colors.green.shade400,
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  Text(
                    'No configuration needed',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'This playbook works without any additional configuration.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (hasConfig)
          FilledButton(
            onPressed: () => Navigator.pop(context, _config),
            child: const Text('Save'),
          ),
      ],
    );
  }

  Widget _buildField(PlaybookConfigField field) {
    final theme = Theme.of(context);

    switch (field.type) {
      case ConfigFieldType.boolean:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
          child: Row(
            children: [
              Switch(
                value: _config[field.name] == true,
                onChanged: (value) {
                  setState(() {
                    _config[field.name] = value;
                  });
                },
              ),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${field.name}${field.required ? ' *' : ''}',
                      style: theme.textTheme.bodyLarge,
                    ),
                    if (field.description != null)
                      Text(
                        field.description!,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );

      case ConfigFieldType.select:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
          child: DropdownButtonFormField<String>(
            initialValue: _config[field.name]?.toString(),
            decoration: InputDecoration(
              labelText: '${field.name}${field.required ? ' *' : ''}',
              helperText: field.description,
              border: const OutlineInputBorder(),
            ),
            items: field.options
                ?.map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                .toList(),
            onChanged: (value) {
              setState(() {
                _config[field.name] = value;
              });
            },
          ),
        );

      case ConfigFieldType.number:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
          child: TextField(
            controller: _controllers[field.name],
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '${field.name}${field.required ? ' *' : ''}',
              helperText: field.description,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              _config[field.name] = num.tryParse(value) ?? value;
            },
          ),
        );

      case ConfigFieldType.string:
      case ConfigFieldType.multiselect:
        final isSecret = field.secret;
        final isObscured = _obscured[field.name] ?? false;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
          child: TextField(
            controller: _controllers[field.name],
            obscureText: isSecret && isObscured,
            decoration: InputDecoration(
              labelText: '${field.name}${field.required ? ' *' : ''}',
              helperText: field.description,
              border: const OutlineInputBorder(),
              prefixIcon: isSecret ? const Icon(Icons.key) : null,
              suffixIcon: isSecret
                  ? IconButton(
                      icon: Icon(
                        isObscured ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscured[field.name] = !isObscured;
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              _config[field.name] = value;
            },
          ),
        );
    }
  }
}

/// Empty state when no playbook is selected
class _EmptyState extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onNew;

  const _EmptyState({required this.onImport, required this.onNew});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 64,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(
            'Select a playbook or create a new one',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: AppConstants.spacingL),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.file_upload),
                label: const Text('Import'),
              ),
              const SizedBox(width: AppConstants.spacingM),
              FilledButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add),
                label: const Text('New Playbook'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
