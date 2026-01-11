import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../models/playbook.dart';
import '../../services/playbook_service.dart';

/// Mobile screen for managing playbooks
class MobilePlaybooksScreen extends StatefulWidget {
  const MobilePlaybooksScreen({super.key});

  @override
  State<MobilePlaybooksScreen> createState() => _MobilePlaybooksScreenState();
}

class _MobilePlaybooksScreenState extends State<MobilePlaybooksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaybookService>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final service = context.watch<PlaybookService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playbooks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import',
            onPressed: _importPlaybook,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New',
            onPressed: _createNewPlaybook,
          ),
        ],
      ),
      body: service.isLoading
          ? const Center(child: CircularProgressIndicator())
          : service.playbooks.isEmpty
          ? _EmptyState(onImport: _importPlaybook, onNew: _createNewPlaybook)
          : ListView.builder(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              itemCount: service.playbooks.length,
              itemBuilder: (context, index) {
                final playbook = service.playbooks[index];
                return _PlaybookCard(
                  playbook: playbook,
                  onTap: () => _showPlaybookDetail(playbook),
                );
              },
            ),
    );
  }

  Future<void> _importPlaybook() async {
    try {
      final service = context.read<PlaybookService>();
      final playbook = await service.importFromFile();
      if (playbook != null && mounted) {
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const _PlaybookEditorScreen()),
    );
  }

  void _showPlaybookDetail(Playbook playbook) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PlaybookDetailScreen(playbook: playbook),
      ),
    );
  }
}

/// Card for displaying a playbook in the list
class _PlaybookCard extends StatelessWidget {
  final Playbook playbook;
  final VoidCallback onTap;

  const _PlaybookCard({required this.playbook, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: playbook.enabled
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : theme.disabledColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIcon(playbook),
                  size: 24,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            playbook.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: playbook.enabled
                                  ? null
                                  : theme.disabledColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'v${playbook.version}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (playbook.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        playbook.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: playbook.enabled ? 0.7 : 0.4,
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppConstants.spacingS),
                    Row(
                      children: [
                        _StatusChip(
                          icon: playbook.enabled
                              ? Icons.check_circle
                              : Icons.pause_circle,
                          label: playbook.enabled ? 'Enabled' : 'Disabled',
                          color: playbook.enabled ? Colors.green : Colors.grey,
                        ),
                        if (!playbook.isConfigured) ...[
                          const SizedBox(width: AppConstants.spacingS),
                          _StatusChip(
                            icon: Icons.warning_amber,
                            label: 'Setup needed',
                            color: Colors.orange,
                          ),
                        ],
                        const Spacer(),
                        Text(
                          '${playbook.actions.length} action${playbook.actions.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spacingS),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(Playbook playbook) {
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

/// Small status chip
class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Detail screen for a playbook
class _PlaybookDetailScreen extends StatelessWidget {
  final Playbook playbook;

  const _PlaybookDetailScreen({required this.playbook});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.watch<PlaybookService>();

    // Get latest playbook data
    final currentPlaybook = service.getPlaybook(playbook.id) ?? playbook;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentPlaybook.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: () => _editPlaybook(context, currentPlaybook),
          ),
          PopupMenuButton<String>(
            onSelected: (action) =>
                _handleAction(context, action, currentPlaybook),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text('Export'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentPlaybook.name,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: AppConstants.spacingS,
                                runSpacing: 4,
                                children: [
                                  _InfoBadge(
                                    icon: Icons.tag,
                                    text: 'v${currentPlaybook.version}',
                                  ),
                                  if (currentPlaybook.author != null)
                                    _InfoBadge(
                                      icon: Icons.person_outline,
                                      text: currentPlaybook.author!,
                                    ),
                                  _InfoBadge(
                                    icon: Icons.api,
                                    text:
                                        'SDK v${currentPlaybook.playbookVersion}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: currentPlaybook.enabled,
                          onChanged: (enabled) {
                            service.setEnabled(currentPlaybook.id, enabled);
                          },
                        ),
                      ],
                    ),
                    if (currentPlaybook.description != null) ...[
                      const SizedBox(height: AppConstants.spacingM),
                      Text(
                        currentPlaybook.description!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Configuration warning
            if (!currentPlaybook.isConfigured) ...[
              const SizedBox(height: AppConstants.spacingM),
              Card(
                color: Colors.orange.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spacingM),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade700),
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
                              'Missing: ${currentPlaybook.missingConfig.map((c) => c.name).join(", ")}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Configure button
            if (currentPlaybook.config.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingM),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _showConfigSheet(context, currentPlaybook),
                  icon: const Icon(Icons.settings),
                  label: const Text('Configure'),
                ),
              ),
            ],

            const SizedBox(height: AppConstants.spacingL),

            // Triggers section
            if (currentPlaybook.triggers.isNotEmpty) ...[
              _SectionHeader(title: 'Triggers'),
              ...currentPlaybook.triggers.map(
                (trigger) => Card(
                  margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
                  child: ListTile(
                    leading: const Icon(Icons.bolt),
                    title: Text(
                      trigger.pattern,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                    subtitle: trigger.description != null
                        ? Text(trigger.description!)
                        : null,
                    trailing: Text(
                      'Priority ${trigger.priority}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacingM),
            ],

            // Actions section
            _SectionHeader(title: 'Actions'),
            ...currentPlaybook.actions.map(
              (action) => _ActionCard(action: action),
            ),

            const SizedBox(height: AppConstants.spacingL),

            // Platforms section
            _SectionHeader(title: 'Supported Platforms'),
            Wrap(
              spacing: AppConstants.spacingS,
              runSpacing: AppConstants.spacingS,
              children: currentPlaybook.platforms.map((p) {
                return Chip(
                  avatar: Icon(_getPlatformIcon(p), size: 18),
                  label: Text(p.name),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _editPlaybook(BuildContext context, Playbook playbook) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PlaybookEditorScreen(playbook: playbook),
      ),
    );
  }

  void _handleAction(
    BuildContext context,
    String action,
    Playbook playbook,
  ) async {
    final service = context.read<PlaybookService>();

    switch (action) {
      case 'export':
        try {
          await service.exportToFile(playbook);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Exported "${playbook.name}"')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Failed to export: $e')));
          }
        }
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Playbook'),
            content: Text(
              'Are you sure you want to delete "${playbook.name}"?',
            ),
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

        if (confirmed == true && context.mounted) {
          await service.removePlaybook(playbook.id);
          Navigator.pop(context);
        }
        break;
    }
  }

  void _showConfigSheet(BuildContext context, Playbook playbook) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ConfigSheet(playbook: playbook),
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

/// Info badge widget
class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(text, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Section header
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppConstants.spacingS,
        bottom: AppConstants.spacingS,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}

/// Action card
class _ActionCard extends StatelessWidget {
  final PlaybookAction action;

  const _ActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.play_arrow, size: 20),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(
                  child: Text(
                    action.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${action.steps.length} steps',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (action.description != null) ...[
              const SizedBox(height: 4),
              Text(action.description!, style: theme.textTheme.bodySmall),
            ],
            if (action.parameters.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingS),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: action.parameters.map((param) {
                  return Chip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      '${param.name}${param.required ? '*' : ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Configuration sheet
class _ConfigSheet extends StatefulWidget {
  final Playbook playbook;

  const _ConfigSheet({required this.playbook});

  @override
  State<_ConfigSheet> createState() => _ConfigSheetState();
}

class _ConfigSheetState extends State<_ConfigSheet> {
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

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
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
                    const Icon(Icons.settings),
                    const SizedBox(width: AppConstants.spacingS),
                    Expanded(
                      child: Text(
                        'Configure ${widget.playbook.name}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    if (hasConfig)
                      FilledButton(onPressed: _save, child: const Text('Save')),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Config fields
              Expanded(
                child: hasConfig
                    ? ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(AppConstants.spacingM),
                        children: widget.playbook.config
                            .map((field) => _buildField(field))
                            .toList(),
                      )
                    : Center(
                        child: Column(
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
                              'This playbook works without any setup.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildField(PlaybookConfigField field) {
    switch (field.type) {
      case ConfigFieldType.boolean:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
          child: Card(
            child: SwitchListTile(
              value: _config[field.name] == true,
              onChanged: (value) {
                setState(() {
                  _config[field.name] = value;
                });
              },
              title: Text('${field.name}${field.required ? ' *' : ''}'),
              subtitle: field.description != null
                  ? Text(field.description!)
                  : null,
            ),
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
              prefixIcon: const Icon(Icons.numbers),
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
              prefixIcon: Icon(isSecret ? Icons.key : Icons.text_fields),
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

  void _save() async {
    await context.read<PlaybookService>().updateConfig(
      widget.playbook.id,
      _config,
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Configuration saved')));
    }
  }
}

/// Playbook editor screen
class _PlaybookEditorScreen extends StatefulWidget {
  final Playbook? playbook;

  const _PlaybookEditorScreen({this.playbook});

  @override
  State<_PlaybookEditorScreen> createState() => _PlaybookEditorScreenState();
}

class _PlaybookEditorScreenState extends State<_PlaybookEditorScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text:
          widget.playbook?.sourceYaml ??
          widget.playbook?.toYaml() ??
          _getTemplate(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playbook != null ? 'Edit Playbook' : 'New Playbook'),
        actions: [
          FilledButton(onPressed: _save, child: const Text('Save')),
          const SizedBox(width: AppConstants.spacingS),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter playbook YAML...',
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    try {
      final service = context.read<PlaybookService>();
      final playbook = await service.importFromYaml(_controller.text);
      if (mounted) {
        Navigator.pop(context);
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

  String _getTemplate() {
    return '''name: My Playbook
version: 1.0.0
description: A custom playbook
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
    description: API key
    secret: true

triggers:
  - pattern: "keyword"
    description: Trigger description

actions:
  myAction:
    description: Action description
    parameters:
      query:
        type: string
        required: true
    steps:
      - type: http
        method: GET
        url: "https://api.example.com"
        response:
          store: result
      - type: returnData
        data: "{{result}}"
''';
  }
}

/// Empty state
class _EmptyState extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onNew;

  const _EmptyState({required this.onImport, required this.onNew});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 64,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text('No Playbooks Yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'Playbooks let you extend Docan with custom integrations.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
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
                  label: const Text('Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
