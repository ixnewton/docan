import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:yaml/yaml.dart';
import 'package:uuid/uuid.dart';

/// Supported platforms for playbooks
enum PlaybookPlatform {
  android,
  ios,
  linux,
  macos,
  windows,
  web;

  static PlaybookPlatform? fromString(String value) {
    return PlaybookPlatform.values.where((p) => p.name == value).firstOrNull;
  }
}

/// Playbook configuration field types
enum ConfigFieldType {
  string,
  number,
  boolean,
  select,
  multiselect;

  static ConfigFieldType fromString(String value) {
    return ConfigFieldType.values.where((t) => t.name == value).firstOrNull ??
        ConfigFieldType.string;
  }
}

/// A configuration field for a playbook
class PlaybookConfigField {
  final String name;
  final ConfigFieldType type;
  final bool required;
  final String? description;
  final bool secret;
  final dynamic defaultValue;
  final List<String>? options; // For select/multiselect types

  const PlaybookConfigField({
    required this.name,
    required this.type,
    this.required = false,
    this.description,
    this.secret = false,
    this.defaultValue,
    this.options,
  });

  factory PlaybookConfigField.fromYaml(String name, YamlMap yaml) {
    return PlaybookConfigField(
      name: name,
      type: ConfigFieldType.fromString(yaml['type']?.toString() ?? 'string'),
      required: yaml['required'] == true,
      description: yaml['description']?.toString(),
      secret: yaml['secret'] == true,
      defaultValue: yaml['default'],
      options: (yaml['options'] as YamlList?)?.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type.name,
    'required': required,
    'description': description,
    'secret': secret,
    'default': defaultValue,
    'options': options,
  };

  factory PlaybookConfigField.fromJson(Map<String, dynamic> json) {
    return PlaybookConfigField(
      name: json['name'] ?? '',
      type: ConfigFieldType.fromString(json['type'] ?? 'string'),
      required: json['required'] ?? false,
      description: json['description'],
      secret: json['secret'] ?? false,
      defaultValue: json['default'],
      options: (json['options'] as List?)?.map((e) => e.toString()).toList(),
    );
  }
}

/// A trigger that determines when a playbook should be considered
class PlaybookTrigger {
  final String pattern; // Regex pattern to match user input
  final String? description;
  final int priority; // Higher priority = checked first

  const PlaybookTrigger({
    required this.pattern,
    this.description,
    this.priority = 0,
  });

  factory PlaybookTrigger.fromYaml(YamlMap yaml) {
    return PlaybookTrigger(
      pattern: yaml['pattern']?.toString() ?? '',
      description: yaml['description']?.toString(),
      priority: yaml['priority'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'pattern': pattern,
    'description': description,
    'priority': priority,
  };

  factory PlaybookTrigger.fromJson(Map<String, dynamic> json) {
    return PlaybookTrigger(
      pattern: json['pattern'] ?? '',
      description: json['description'],
      priority: json['priority'] ?? 0,
    );
  }

  /// Check if this trigger matches the given input
  bool matches(String input) {
    try {
      return RegExp(pattern, caseSensitive: false).hasMatch(input);
    } catch (e) {
      debugPrint('[Playbook] Invalid trigger pattern: $pattern');
      return false;
    }
  }
}

/// HTTP request step type
enum HttpMethod { get, post, put, patch, delete }

/// Step types for playbook actions
enum StepType {
  http,
  webhook,
  transform,
  condition,
  loop,
  setVariable,
  returnData,
  askUser,
  askAI;

  static StepType fromString(String value) {
    return StepType.values.where((t) => t.name == value).firstOrNull ??
        StepType.http;
  }
}

/// A step in a playbook action
class PlaybookStep {
  final StepType type;
  final Map<String, dynamic> config;

  const PlaybookStep({
    required this.type,
    required this.config,
  });

  factory PlaybookStep.fromYaml(YamlMap yaml) {
    final typeStr = yaml['type']?.toString() ?? 'http';
    final config = <String, dynamic>{};
    
    yaml.forEach((key, value) {
      if (key != 'type') {
        config[key.toString()] = _convertYamlValue(value);
      }
    });

    return PlaybookStep(
      type: StepType.fromString(typeStr),
      config: config,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    ...config,
  };

  factory PlaybookStep.fromJson(Map<String, dynamic> json) {
    final type = StepType.fromString(json['type'] ?? 'http');
    final config = Map<String, dynamic>.from(json)..remove('type');
    return PlaybookStep(type: type, config: config);
  }
}

/// A parameter for a playbook action
class ActionParameter {
  final String name;
  final String type;
  final bool required;
  final String? description;
  final dynamic defaultValue;

  const ActionParameter({
    required this.name,
    required this.type,
    this.required = false,
    this.description,
    this.defaultValue,
  });

  factory ActionParameter.fromYaml(String name, YamlMap yaml) {
    return ActionParameter(
      name: name,
      type: yaml['type']?.toString() ?? 'string',
      required: yaml['required'] == true,
      description: yaml['description']?.toString(),
      defaultValue: yaml['default'],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'required': required,
    'description': description,
    'default': defaultValue,
  };

  factory ActionParameter.fromJson(Map<String, dynamic> json) {
    return ActionParameter(
      name: json['name'] ?? '',
      type: json['type'] ?? 'string',
      required: json['required'] ?? false,
      description: json['description'],
      defaultValue: json['default'],
    );
  }
}

/// An action that a playbook can perform
class PlaybookAction {
  final String name;
  final String? description;
  final List<ActionParameter> parameters;
  final List<PlaybookStep> steps;
  final Map<String, dynamic>? returns;

  const PlaybookAction({
    required this.name,
    this.description,
    this.parameters = const [],
    this.steps = const [],
    this.returns,
  });

  factory PlaybookAction.fromYaml(String name, YamlMap yaml) {
    final params = <ActionParameter>[];
    final paramsYaml = yaml['parameters'] as YamlMap?;
    paramsYaml?.forEach((key, value) {
      if (value is YamlMap) {
        params.add(ActionParameter.fromYaml(key.toString(), value));
      }
    });

    final steps = <PlaybookStep>[];
    final stepsYaml = yaml['steps'] as YamlList?;
    for (final step in stepsYaml ?? []) {
      if (step is YamlMap) {
        steps.add(PlaybookStep.fromYaml(step));
      }
    }

    return PlaybookAction(
      name: name,
      description: yaml['description']?.toString(),
      parameters: params,
      steps: steps,
      returns: _convertYamlValue(yaml['returns']) as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'parameters': parameters.map((p) => p.toJson()).toList(),
    'steps': steps.map((s) => s.toJson()).toList(),
    'returns': returns,
  };

  factory PlaybookAction.fromJson(Map<String, dynamic> json) {
    return PlaybookAction(
      name: json['name'] ?? '',
      description: json['description'],
      parameters: (json['parameters'] as List?)
          ?.map((p) => ActionParameter.fromJson(p))
          .toList() ?? [],
      steps: (json['steps'] as List?)
          ?.map((s) => PlaybookStep.fromJson(s))
          .toList() ?? [],
      returns: json['returns'],
    );
  }
}

/// Main Playbook model
class Playbook {
  final String id;
  final String name;
  final String version;
  final String? description;
  final String? author;
  final String? repository;
  final String? license;
  final int playbookVersion; // SDK version
  final List<PlaybookPlatform> platforms;
  final List<PlaybookConfigField> config;
  final List<PlaybookTrigger> triggers;
  final List<PlaybookAction> actions;
  final String? icon;
  final Map<String, dynamic> userConfig; // User-provided config values
  final bool enabled;
  final DateTime? installedAt;
  final String? sourceYaml; // Original YAML content

  Playbook({
    String? id,
    required this.name,
    required this.version,
    this.description,
    this.author,
    this.repository,
    this.license,
    this.playbookVersion = 1,
    this.platforms = const [],
    this.config = const [],
    this.triggers = const [],
    this.actions = const [],
    this.icon,
    this.userConfig = const {},
    this.enabled = true,
    this.installedAt,
    this.sourceYaml,
  }) : id = id ?? const Uuid().v4();

  /// Parse a playbook from YAML string
  factory Playbook.fromYaml(String yamlContent) {
    final yaml = loadYaml(yamlContent) as YamlMap;

    // Parse platforms
    final platforms = <PlaybookPlatform>[];
    final platformsYaml = yaml['platforms'] as YamlList?;
    for (final p in platformsYaml ?? []) {
      final platform = PlaybookPlatform.fromString(p.toString());
      if (platform != null) platforms.add(platform);
    }

    // Parse config fields
    final config = <PlaybookConfigField>[];
    final configYaml = yaml['config'] as YamlMap?;
    configYaml?.forEach((key, value) {
      if (value is YamlMap) {
        config.add(PlaybookConfigField.fromYaml(key.toString(), value));
      }
    });

    // Parse triggers
    final triggers = <PlaybookTrigger>[];
    final triggersYaml = yaml['triggers'] as YamlList?;
    for (final t in triggersYaml ?? []) {
      if (t is YamlMap) {
        triggers.add(PlaybookTrigger.fromYaml(t));
      }
    }

    // Parse actions
    final actions = <PlaybookAction>[];
    final actionsYaml = yaml['actions'] as YamlMap?;
    actionsYaml?.forEach((key, value) {
      if (value is YamlMap) {
        actions.add(PlaybookAction.fromYaml(key.toString(), value));
      }
    });

    return Playbook(
      name: yaml['name']?.toString() ?? 'Unnamed Playbook',
      version: yaml['version']?.toString() ?? '1.0.0',
      description: yaml['description']?.toString(),
      author: yaml['author']?.toString(),
      repository: yaml['repository']?.toString(),
      license: yaml['license']?.toString(),
      playbookVersion: yaml['playbookVersion'] as int? ?? 1,
      platforms: platforms.isEmpty ? PlaybookPlatform.values.toList() : platforms,
      config: config,
      triggers: triggers,
      actions: actions,
      icon: yaml['icon']?.toString(),
      installedAt: DateTime.now(),
      sourceYaml: yamlContent,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'description': description,
    'author': author,
    'repository': repository,
    'license': license,
    'playbookVersion': playbookVersion,
    'platforms': platforms.map((p) => p.name).toList(),
    'config': config.map((c) => c.toJson()).toList(),
    'triggers': triggers.map((t) => t.toJson()).toList(),
    'actions': actions.map((a) => a.toJson()).toList(),
    'icon': icon,
    'userConfig': userConfig,
    'enabled': enabled,
    'installedAt': installedAt?.toIso8601String(),
    'sourceYaml': sourceYaml,
  };

  /// Parse from JSON
  factory Playbook.fromJson(Map<String, dynamic> json) {
    return Playbook(
      id: json['id'],
      name: json['name'] ?? 'Unnamed',
      version: json['version'] ?? '1.0.0',
      description: json['description'],
      author: json['author'],
      repository: json['repository'],
      license: json['license'],
      playbookVersion: json['playbookVersion'] ?? 1,
      platforms: (json['platforms'] as List?)
          ?.map((p) => PlaybookPlatform.fromString(p.toString()))
          .whereType<PlaybookPlatform>()
          .toList() ?? [],
      config: (json['config'] as List?)
          ?.map((c) => PlaybookConfigField.fromJson(c))
          .toList() ?? [],
      triggers: (json['triggers'] as List?)
          ?.map((t) => PlaybookTrigger.fromJson(t))
          .toList() ?? [],
      actions: (json['actions'] as List?)
          ?.map((a) => PlaybookAction.fromJson(a))
          .toList() ?? [],
      icon: json['icon'],
      userConfig: Map<String, dynamic>.from(json['userConfig'] ?? {}),
      enabled: json['enabled'] ?? true,
      installedAt: json['installedAt'] != null 
          ? DateTime.parse(json['installedAt']) 
          : null,
      sourceYaml: json['sourceYaml'],
    );
  }

  /// Create a copy with updated fields
  Playbook copyWith({
    String? id,
    String? name,
    String? version,
    String? description,
    String? author,
    String? repository,
    String? license,
    int? playbookVersion,
    List<PlaybookPlatform>? platforms,
    List<PlaybookConfigField>? config,
    List<PlaybookTrigger>? triggers,
    List<PlaybookAction>? actions,
    String? icon,
    Map<String, dynamic>? userConfig,
    bool? enabled,
    DateTime? installedAt,
    String? sourceYaml,
  }) {
    return Playbook(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      description: description ?? this.description,
      author: author ?? this.author,
      repository: repository ?? this.repository,
      license: license ?? this.license,
      playbookVersion: playbookVersion ?? this.playbookVersion,
      platforms: platforms ?? this.platforms,
      config: config ?? this.config,
      triggers: triggers ?? this.triggers,
      actions: actions ?? this.actions,
      icon: icon ?? this.icon,
      userConfig: userConfig ?? this.userConfig,
      enabled: enabled ?? this.enabled,
      installedAt: installedAt ?? this.installedAt,
      sourceYaml: sourceYaml ?? this.sourceYaml,
    );
  }

  /// Check if playbook is supported on current platform
  bool get isSupported {
    final currentPlatform = _getCurrentPlatform();
    return currentPlatform == null || platforms.contains(currentPlatform);
  }

  /// Get action by name
  PlaybookAction? getAction(String name) {
    return actions.where((a) => a.name == name).firstOrNull;
  }

  /// Check if all required config is provided
  bool get isConfigured {
    for (final field in config) {
      if (field.required && !userConfig.containsKey(field.name)) {
        return false;
      }
    }
    return true;
  }

  /// Get list of missing required config fields
  List<PlaybookConfigField> get missingConfig {
    return config.where((f) => f.required && !userConfig.containsKey(f.name)).toList();
  }

  static PlaybookPlatform? _getCurrentPlatform() {
    if (kIsWeb) return PlaybookPlatform.web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return PlaybookPlatform.android;
      case TargetPlatform.iOS:
        return PlaybookPlatform.ios;
      case TargetPlatform.linux:
        return PlaybookPlatform.linux;
      case TargetPlatform.macOS:
        return PlaybookPlatform.macos;
      case TargetPlatform.windows:
        return PlaybookPlatform.windows;
      default:
        return null;
    }
  }

  /// Export to YAML string
  String toYaml() {
    if (sourceYaml != null) return sourceYaml!;
    
    // Generate YAML from model
    final buffer = StringBuffer();
    buffer.writeln('name: $name');
    buffer.writeln('version: $version');
    if (description != null) buffer.writeln('description: $description');
    if (author != null) buffer.writeln('author: $author');
    if (repository != null) buffer.writeln('repository: $repository');
    if (license != null) buffer.writeln('license: $license');
    buffer.writeln('playbookVersion: $playbookVersion');
    
    if (platforms.isNotEmpty) {
      buffer.writeln('platforms:');
      for (final p in platforms) {
        buffer.writeln('  - ${p.name}');
      }
    }
    
    // Add more serialization as needed...
    return buffer.toString();
  }
}

/// Result of executing a playbook action
class PlaybookResult {
  final bool success;
  final dynamic data;
  final String? error;
  final String? message;
  final Map<String, dynamic>? context;

  const PlaybookResult({
    required this.success,
    this.data,
    this.error,
    this.message,
    this.context,
  });

  factory PlaybookResult.success({dynamic data, String? message, Map<String, dynamic>? context}) {
    return PlaybookResult(success: true, data: data, message: message, context: context);
  }

  factory PlaybookResult.failure(String error, {Map<String, dynamic>? context}) {
    return PlaybookResult(success: false, error: error, context: context);
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'data': data,
    'error': error,
    'message': message,
    'context': context,
  };
}

/// Helper to convert YAML values to Dart types
dynamic _convertYamlValue(dynamic value) {
  if (value is YamlMap) {
    final map = <String, dynamic>{};
    value.forEach((k, v) {
      map[k.toString()] = _convertYamlValue(v);
    });
    return map;
  } else if (value is YamlList) {
    return value.map(_convertYamlValue).toList();
  }
  return value;
}
