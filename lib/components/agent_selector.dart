import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/agent_config.dart';
import '../models/ai_provider.dart';
import '../utils/liquid_glass_effects.dart';

/// Agent preset selector
class AgentSelector extends StatelessWidget {
  final AgentPreset? selectedAgent;
  final ValueChanged<AgentPreset?> onAgentChanged;
  final List<AgentPreset> customAgents;
  final bool compact;

  const AgentSelector({
    super.key,
    this.selectedAgent,
    required this.onAgentChanged,
    this.customAgents = const [],
    this.compact = false,
  });

  List<AgentPreset> get _allAgents => [
        ...AgentPreset.defaults,
        ...customAgents,
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showAgentPicker(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: AppConstants.hoverDuration,
          padding: EdgeInsets.symmetric(
            horizontal: AppConstants.spacingM,
            vertical: AppConstants.spacingS,
          ),
          decoration: BoxDecoration(
            color: selectedAgent != null
                ? selectedAgent!.accentColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.radiusS),
            border: Border.all(
              color: selectedAgent != null
                  ? selectedAgent!.accentColor.withValues(alpha: 0.3)
                  : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selectedAgent?.icon ?? Icons.person_outline,
                size: 18,
                color: selectedAgent?.accentColor ?? theme.iconTheme.color,
              ),
              if (!compact) ...[
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  selectedAgent?.name ?? 'Default',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selectedAgent?.accentColor,
                  ),
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

  void _showAgentPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => LiquidGlassContainer(
          borderRadius: AppConstants.radiusL,
          margin: const EdgeInsets.all(AppConstants.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                child: Row(
                  children: [
                    Text(
                      'Select Agent',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (selectedAgent != null)
                      TextButton(
                        onPressed: () {
                          onAgentChanged(null);
                          Navigator.pop(context);
                        },
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _allAgents.length,
                  itemBuilder: (context, index) {
                    final agent = _allAgents[index];
                    return _AgentTile(
                      agent: agent,
                      isSelected: selectedAgent?.id == agent.id,
                      onTap: () {
                        onAgentChanged(agent);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentTile extends StatelessWidget {
  final AgentPreset agent;
  final bool isSelected;
  final VoidCallback onTap;

  const _AgentTile({
    required this.agent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: agent.accentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppConstants.radiusS),
        ),
        child: Icon(
          agent.icon,
          color: agent.accentColor,
          size: 22,
        ),
      ),
      title: Text(
        agent.name,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            agent.description,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                agent.provider.icon,
                size: 12,
                color: agent.provider.color,
              ),
              const SizedBox(width: 4),
              Text(
                agent.modelId,
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(width: 8),
              Text(
                'Temp: ${agent.temperature}',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: theme.primaryColor)
          : null,
      onTap: onTap,
    );
  }
}
