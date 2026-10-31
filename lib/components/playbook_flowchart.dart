import 'package:flutter/material.dart';

import '../models/playbook.dart';

/// Visual flow of a playbook: triggers, then each action with its steps.
/// Step nodes are tappable for editing when [onEditStep] is provided.
class PlaybookFlowchart extends StatelessWidget {
  final Playbook playbook;
  final void Function(String actionName, int stepIndex)? onEditStep;

  const PlaybookFlowchart({
    super.key,
    required this.playbook,
    this.onEditStep,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (playbook.triggers.isNotEmpty) ...[
          _sectionLabel(context, 'Triggers', Icons.bolt_outlined),
          ...playbook.triggers.map(
            (trigger) => _Node(
              icon: Icons.bolt,
              color: Colors.orange,
              title: trigger.pattern,
              subtitle: trigger.description,
            ),
          ),
        ],
        for (final action in playbook.actions) ...[
          if (playbook.triggers.isNotEmpty || action != playbook.actions.first)
            const SizedBox(height: 8),
          _sectionLabel(context, 'Action: ${action.name}', Icons.play_arrow),
          _StepsFlow(
            action: action,
            onEditStep: onEditStep,
            indent: 0,
          ),
        ],
        if (playbook.actions.isEmpty)
          Text(
            'This playbook has no actions yet.',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _sectionLabel(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsFlow extends StatelessWidget {
  final PlaybookAction action;
  final void Function(String actionName, int stepIndex)? onEditStep;
  final int indent;

  const _StepsFlow({
    required this.action,
    required this.onEditStep,
    required this.indent,
  });

  @override
  Widget build(BuildContext context) {
    final steps = action.steps;
    if (steps.isEmpty) {
      final theme = Theme.of(context);
      return Padding(
        padding: EdgeInsets.only(left: indent.toDouble()),
        child: Text('No steps', style: theme.textTheme.bodySmall),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _StepNode(
            actionName: action.name,
            stepIndex: i,
            step: steps[i],
            indent: indent,
            onEditStep: onEditStep,
          ),
          ..._nestedBranches(context, steps[i]),
          if (i < steps.length - 1) _arrow(indent: indent),
        ],
      ],
    );
  }

  List<Widget> _nestedBranches(BuildContext context, PlaybookStep step) {
    final theme = Theme.of(context);
    if (step.type == StepType.condition) {
      final thenSteps = step.config['then'];
      final elseSteps = step.config['else'];
      return [
        for (final entry in [
          ('then', thenSteps),
          ('else', elseSteps),
        ])
          if (entry.$2 is List && (entry.$2 as List).isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(left: indent + 10.0, top: 2),
              child: Row(
                children: [
                  Icon(
                    entry.$1 == 'then' ? Icons.subdirectory_arrow_right : null,
                    size: 12,
                    color: Colors.orange,
                  ),
                  Text(
                    entry.$1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            _NestedSteps(
              steps: entry.$2 as List,
              indent: indent + 16,
            ),
          ],
      ];
    }
    if (step.type == StepType.loop) {
      final loopSteps = step.config['steps'];
      if (loopSteps is List && loopSteps.isNotEmpty) {
        return [
          _NestedSteps(steps: loopSteps, indent: indent + 16),
        ];
      }
    }
    return const [];
  }

  Widget _arrow({required int indent}) {
    return Padding(
      padding: EdgeInsets.only(left: indent + 15),
      child: const Icon(Icons.south, size: 14, color: Colors.grey),
    );
  }
}

/// Read-only rendering of nested step configs (condition branches, loop bodies)
class _NestedSteps extends StatelessWidget {
  final List steps;
  final int indent;

  const _NestedSteps({required this.steps, required this.indent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _StepNode(
            actionName: '',
            stepIndex: -1,
            step: PlaybookStep.fromJson(steps[i]),
            indent: indent,
            onEditStep: null,
          ),
          if (i < steps.length - 1)
            Padding(
              padding: EdgeInsets.only(left: indent + 15.0),
              child: const Icon(Icons.south, size: 12, color: Colors.grey),
            ),
        ],
      ],
    );
  }
}

class _Node extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;

  const _Node({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  final String actionName;
  final int stepIndex;
  final PlaybookStep step;
  final int indent;
  final void Function(String actionName, int stepIndex)? onEditStep;

  const _StepNode({
    required this.actionName,
    required this.stepIndex,
    required this.step,
    required this.indent,
    required this.onEditStep,
  });

  (IconData, Color) get _visual {
    switch (step.type) {
      case StepType.http:
        return (Icons.cloud_outlined, Colors.blue);
      case StepType.webhook:
        return (Icons.webhook, Colors.teal);
      case StepType.transform:
        return (Icons.shuffle, Colors.deepPurple);
      case StepType.condition:
        return (Icons.alt_route, Colors.orange);
      case StepType.loop:
        return (Icons.loop, Colors.green);
      case StepType.setVariable:
        return (Icons.commit, Colors.brown);
      case StepType.returnData:
        return (Icons.output, Colors.red);
      case StepType.askUser:
      case StepType.askAI:
        return (Icons.help_outline, Colors.grey);
    }
  }

  String get _summary {
    final config = step.config;
    switch (step.type) {
      case StepType.http:
        final method = config['method']?.toString().toUpperCase() ?? 'GET';
        final url = config['url']?.toString() ?? '';
        final host = Uri.tryParse(url)?.host ?? url;
        return '$method $host';
      case StepType.webhook:
        final url = config['url']?.toString() ?? '';
        return Uri.tryParse(url)?.host ?? url;
      case StepType.transform:
        return '→ ${config['output'] ?? 'transform'}';
      case StepType.condition:
        return 'if ${config['if'] ?? ''}';
      case StepType.loop:
        return 'for each ${config['items'] ?? ''}';
      case StepType.setVariable:
        return '${config['name'] ?? ''} = ${config['value'] ?? ''}';
      case StepType.returnData:
        return config['message']?.toString() ?? 'return data';
      case StepType.askUser:
      case StepType.askAI:
        return step.type.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _visual;
    final node = Container(
      margin: EdgeInsets.only(left: indent.toDouble()),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.type.name,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (onEditStep != null)
            Icon(Icons.edit_outlined, size: 14, color: Colors.grey.shade500),
        ],
      ),
    );

    if (onEditStep == null) return node;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onEditStep!(actionName, stepIndex),
      child: node,
    );
  }
}
