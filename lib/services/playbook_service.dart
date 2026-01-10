import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playbook.dart';
import 'playbook_executor.dart';

/// Service for managing playbooks
class PlaybookService extends ChangeNotifier {
  static const String _storageKey = 'docan_playbooks';
  static const String _configKey = 'docan_playbook_configs';
  static const String _secretPrefix = 'playbook_secret_';

  final List<Playbook> _playbooks = [];
  final PlaybookExecutor _executor;
  final FlutterSecureStorage _secureStorage;
  bool _isLoading = false;
  String? _error;

  PlaybookService()
    : _executor = PlaybookExecutor(),
      _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  // Getters
  List<Playbook> get playbooks => List.unmodifiable(_playbooks);
  List<Playbook> get enabledPlaybooks =>
      _playbooks.where((p) => p.enabled && p.isSupported).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  PlaybookExecutor get executor => _executor;

  /// Initialize the service
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadPlaybooks();
      await _loadBuiltInPlaybooks();
    } catch (e) {
      _error = 'Failed to initialize playbooks: $e';
      debugPrint('[PlaybookService] $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load playbooks from storage
  Future<void> _loadPlaybooks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);

    if (data != null) {
      try {
        final list = jsonDecode(data) as List;
        _playbooks.clear();
        for (final item in list) {
          try {
            _playbooks.add(Playbook.fromJson(item));
          } catch (e) {
            debugPrint('[PlaybookService] Failed to parse playbook: $e');
          }
        }
      } catch (e) {
        debugPrint('[PlaybookService] Failed to load playbooks: $e');
      }
    }

    // Load user configs (non-secret values from SharedPreferences)
    final configs = prefs.getString(_configKey);
    Map<String, dynamic> configMap = {};
    if (configs != null) {
      try {
        configMap = jsonDecode(configs) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('[PlaybookService] Failed to parse config map: $e');
      }
    }

    // Load configs for all playbooks (including secrets)
    for (int i = 0; i < _playbooks.length; i++) {
      final playbook = _playbooks[i];
      final userConfig = Map<String, dynamic>.from(
        configMap[playbook.id] ?? {},
      );

      // Always try to load secret values from secure storage
      await _loadSecretConfigs(playbook.id, playbook, userConfig);

      if (userConfig.isNotEmpty) {
        _playbooks[i] = playbook.copyWith(userConfig: userConfig);
      }
    }
  }

  /// Load secret config values from secure storage
  Future<void> _loadSecretConfigs(
    String playbookId,
    Playbook playbook,
    Map<String, dynamic> userConfig,
  ) async {
    for (final configDef in playbook.config) {
      if (configDef.secret) {
        try {
          final secretKey = '$_secretPrefix${playbookId}_${configDef.name}';
          final secretValue = await _secureStorage.read(key: secretKey);
          if (secretValue != null) {
            userConfig[configDef.name] = secretValue;
          }
        } catch (e) {
          debugPrint(
            '[PlaybookService] Failed to load secret ${configDef.name}: $e',
          );
        }
      }
    }
  }

  /// Load built-in playbooks from assets
  Future<void> _loadBuiltInPlaybooks() async {
    // List of built-in playbook files
    final builtInPlaybooks = [
      'assets/playbooks/openlyst.yaml',
    ];

    for (final path in builtInPlaybooks) {
      try {
        final yaml = await rootBundle.loadString(path);
        final playbook = Playbook.fromYaml(yaml);

        // Check if already installed
        final existing = _playbooks
            .where((p) => p.name == playbook.name)
            .firstOrNull;
        if (existing == null) {
          _playbooks.add(playbook);
        }
      } catch (e) {
        debugPrint(
          '[PlaybookService] Failed to load built-in playbook $path: $e',
        );
      }
    }
  }

  /// Save playbooks to storage
  Future<void> _savePlaybooks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_playbooks.map((p) => p.toJson()).toList());
    await prefs.setString(_storageKey, data);

    // Save configs (separate secrets from non-secrets)
    final configs = <String, dynamic>{};
    for (final playbook in _playbooks) {
      if (playbook.userConfig.isNotEmpty) {
        final nonSecretConfig = <String, dynamic>{};

        for (final entry in playbook.userConfig.entries) {
          final configDef = playbook.config
              .where((c) => c.name == entry.key)
              .firstOrNull;
          if (configDef?.secret == true) {
            // Save secret to secure storage
            await _saveSecret(
              playbook.id,
              entry.key,
              entry.value?.toString() ?? '',
            );
          } else {
            // Save non-secret to SharedPreferences
            nonSecretConfig[entry.key] = entry.value;
          }
        }

        // Always store an entry if there's any config (even if all secrets)
        // This helps track that this playbook has been configured
        configs[playbook.id] = nonSecretConfig;
      }
    }
    await prefs.setString(_configKey, jsonEncode(configs));
  }

  /// Save a secret value to secure storage
  Future<void> _saveSecret(String playbookId, String key, String value) async {
    try {
      final secretKey = '$_secretPrefix${playbookId}_$key';
      if (value.isEmpty) {
        await _secureStorage.delete(key: secretKey);
      } else {
        await _secureStorage.write(key: secretKey, value: value);
      }
    } catch (e) {
      debugPrint('[PlaybookService] Failed to save secret $key: $e');
    }
  }

  /// Delete all secrets for a playbook
  Future<void> _deletePlaybookSecrets(String playbookId) async {
    try {
      final allKeys = await _secureStorage.readAll();
      final prefix = '$_secretPrefix$playbookId';
      for (final key in allKeys.keys) {
        if (key.startsWith(prefix)) {
          await _secureStorage.delete(key: key);
        }
      }
    } catch (e) {
      debugPrint('[PlaybookService] Failed to delete playbook secrets: $e');
    }
  }

  /// Import a playbook from YAML string
  Future<Playbook> importFromYaml(String yaml) async {
    try {
      final playbook = Playbook.fromYaml(yaml);

      // Check if already exists
      final existingIndex = _playbooks.indexWhere(
        (p) => p.name == playbook.name,
      );
      if (existingIndex >= 0) {
        // Update existing
        _playbooks[existingIndex] = playbook.copyWith(
          id: _playbooks[existingIndex].id,
          userConfig: _playbooks[existingIndex].userConfig,
          enabled: _playbooks[existingIndex].enabled,
        );
      } else {
        _playbooks.add(playbook);
      }

      await _savePlaybooks();
      notifyListeners();
      return playbook;
    } catch (e) {
      throw Exception('Failed to parse playbook YAML: $e');
    }
  }

  /// Import a playbook from file
  Future<Playbook?> importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['yaml', 'yml'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      String yaml;
      if (kIsWeb) {
        final bytes = result.files.first.bytes;
        if (bytes == null) return null;
        yaml = utf8.decode(bytes);
      } else {
        final path = result.files.first.path;
        if (path == null) return null;
        yaml = await File(path).readAsString();
      }

      return importFromYaml(yaml);
    } catch (e) {
      throw Exception('Failed to import playbook: $e');
    }
  }

  /// Export a playbook to file
  Future<void> exportToFile(Playbook playbook) async {
    try {
      final yaml = playbook.sourceYaml ?? playbook.toYaml();
      final fileName =
          '${playbook.name.toLowerCase().replaceAll(' ', '_')}.yaml';

      if (kIsWeb) {
        // Web download
        // ignore: avoid_web_libraries_in_flutter
        // final blob = html.Blob([yaml]);
        // final url = html.Url.createObjectUrlFromBlob(blob);
        // html.AnchorElement()
        //   ..href = url
        //   ..download = fileName
        //   ..click();
        // html.Url.revokeObjectUrl(url);
      } else {
        final directory =
            await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(yaml);
        debugPrint('[PlaybookService] Exported playbook to: ${file.path}');
      }
    } catch (e) {
      throw Exception('Failed to export playbook: $e');
    }
  }

  /// Export playbook YAML as string (for sharing)
  String exportToYaml(Playbook playbook) {
    return playbook.sourceYaml ?? playbook.toYaml();
  }

  /// Add a new playbook
  Future<void> addPlaybook(Playbook playbook) async {
    _playbooks.add(playbook);
    await _savePlaybooks();
    notifyListeners();
  }

  /// Remove a playbook
  Future<void> removePlaybook(String id) async {
    await _deletePlaybookSecrets(id);
    _playbooks.removeWhere((p) => p.id == id);
    await _savePlaybooks();
    notifyListeners();
  }

  /// Update playbook enabled state
  Future<void> setEnabled(String id, bool enabled) async {
    final index = _playbooks.indexWhere((p) => p.id == id);
    if (index >= 0) {
      _playbooks[index] = _playbooks[index].copyWith(enabled: enabled);
      await _savePlaybooks();
      notifyListeners();
    }
  }

  /// Update playbook configuration
  Future<void> updateConfig(String id, Map<String, dynamic> config) async {
    final index = _playbooks.indexWhere((p) => p.id == id);
    if (index >= 0) {
      _playbooks[index] = _playbooks[index].copyWith(userConfig: config);
      await _savePlaybooks();
      notifyListeners();
    }
  }

  /// Get playbook by ID
  Playbook? getPlaybook(String id) {
    return _playbooks.where((p) => p.id == id).firstOrNull;
  }

  /// Get playbook by name (case-insensitive)
  Playbook? getPlaybookByName(String name) {
    final normalizedName = name.toLowerCase().trim();
    return _playbooks
        .where(
          (p) =>
              p.name.toLowerCase() == normalizedName ||
              p.name.toLowerCase().replaceAll(' ', '') ==
                  normalizedName.replaceAll(' ', '') ||
              p.name.toLowerCase().replaceAll(' ', '_') ==
                  normalizedName.replaceAll(' ', '_') ||
              p.name.toLowerCase().replaceAll(' ', '-') ==
                  normalizedName.replaceAll(' ', '-'),
        )
        .firstOrNull;
  }

  /// Find playbooks that match a user query
  List<PlaybookMatch> findMatchingPlaybooks(String query) {
    final matches = <PlaybookMatch>[];

    for (final playbook in enabledPlaybooks) {
      if (!playbook.isConfigured) continue;

      for (final trigger in playbook.triggers) {
        if (trigger.matches(query)) {
          matches.add(
            PlaybookMatch(
              playbook: playbook,
              trigger: trigger,
              confidence: _calculateConfidence(query, trigger),
            ),
          );
        }
      }
    }

    // Sort by confidence and priority
    matches.sort((a, b) {
      final priorityCompare = b.trigger.priority.compareTo(a.trigger.priority);
      if (priorityCompare != 0) return priorityCompare;
      return b.confidence.compareTo(a.confidence);
    });

    return matches;
  }

  double _calculateConfidence(String query, PlaybookTrigger trigger) {
    try {
      final regex = RegExp(trigger.pattern, caseSensitive: false);
      final match = regex.firstMatch(query);
      if (match == null) return 0.0;

      // Calculate confidence based on match coverage
      final matchLength = match.group(0)?.length ?? 0;
      final coverage = matchLength / query.length;

      // Boost confidence based on named groups captured
      int groupsMatched = 0;
      for (final name in match.groupNames) {
        if (match.namedGroup(name)?.isNotEmpty == true) {
          groupsMatched++;
        }
      }

      // Fuzzy word matching bonus
      final queryWords = query.toLowerCase().split(RegExp(r'\s+'));
      final patternWords = trigger.pattern
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 2)
          .toSet();

      int wordMatches = 0;
      for (final queryWord in queryWords) {
        for (final patternWord in patternWords) {
          if (queryWord.contains(patternWord) ||
              patternWord.contains(queryWord)) {
            wordMatches++;
            break;
          }
          // Simple Levenshtein-like similarity (within 2 edits)
          if (_isSimilar(queryWord, patternWord, 2)) {
            wordMatches++;
            break;
          }
        }
      }

      final wordBonus = patternWords.isNotEmpty
          ? (wordMatches / patternWords.length) * 0.2
          : 0.0;
      final groupBonus = groupsMatched * 0.1;

      return (coverage * 0.7 + groupBonus + wordBonus).clamp(0.0, 1.0);
    } catch (e) {
      return 0.5; // Default confidence for invalid regex
    }
  }

  /// Simple similarity check (approximates Levenshtein distance ≤ maxDistance)
  bool _isSimilar(String a, String b, int maxDistance) {
    if ((a.length - b.length).abs() > maxDistance) return false;
    if (a == b) return true;
    if (a.isEmpty || b.isEmpty) return false;

    // Quick check: common prefix/suffix
    int commonPrefix = 0;
    int minLen = a.length < b.length ? a.length : b.length;
    while (commonPrefix < minLen && a[commonPrefix] == b[commonPrefix]) {
      commonPrefix++;
    }

    if (commonPrefix >= minLen - maxDistance) return true;

    // Check if one contains the other with small difference
    if (a.contains(b) || b.contains(a)) return true;

    return false;
  }

  /// Execute a playbook action
  Future<PlaybookResult> executeAction(
    Playbook playbook,
    String actionName,
    Map<String, dynamic> parameters, {
    Map<String, dynamic>? context,
  }) async {
    final action = playbook.getAction(actionName);
    if (action == null) {
      return PlaybookResult.failure(
        'Action "$actionName" not found in playbook',
      );
    }

    return _executor.execute(
      playbook: playbook,
      action: action,
      parameters: parameters,
      context: context,
    );
  }

  /// Execute a playbook action with progress streaming
  Stream<PlaybookProgress> executeActionStream(
    Playbook playbook,
    String actionName,
    Map<String, dynamic> parameters, {
    Map<String, dynamic>? context,
  }) async* {
    final action = playbook.getAction(actionName);
    if (action == null) {
      yield PlaybookProgress(
        currentStep: 0,
        totalSteps: 0,
        stepName: 'Error',
        status: PlaybookStepStatus.failed,
        message: 'Action "$actionName" not found in playbook',
        data: PlaybookResult.failure(
          'Action "$actionName" not found in playbook',
        ),
      );
      return;
    }

    yield* _executor.executeStream(
      playbook: playbook,
      action: action,
      parameters: parameters,
      context: context,
    );
  }

  /// Perform a dry run to check if execution will succeed
  DryRunResult dryRunAction(
    Playbook playbook,
    String actionName,
    Map<String, dynamic> parameters,
  ) {
    final action = playbook.getAction(actionName);
    if (action == null) {
      return DryRunResult(
        canRun: false,
        issues: ['Action "$actionName" not found in playbook'],
      );
    }

    return _executor.dryRun(
      playbook: playbook,
      action: action,
      parameters: parameters,
    );
  }

  /// Validate parameters for an action
  List<ValidationError> validateActionParameters(
    Playbook playbook,
    String actionName,
    Map<String, dynamic> parameters,
  ) {
    final action = playbook.getAction(actionName);
    if (action == null) {
      return [ValidationError(field: 'action', message: 'Action not found')];
    }

    return _executor.validateParameters(action, parameters);
  }

  /// Get a summary of available playbooks for AI
  String getPlaybooksSummary() {
    final buffer = StringBuffer();
    buffer.writeln('Available Playbooks:');

    for (final playbook in enabledPlaybooks) {
      if (!playbook.isConfigured) continue;

      buffer.writeln('\n## ${playbook.name}');
      if (playbook.description != null) {
        buffer.writeln(playbook.description);
      }

      buffer.writeln('\nActions:');
      for (final action in playbook.actions) {
        buffer.writeln(
          '- ${action.name}: ${action.description ?? 'No description'}',
        );
        if (action.parameters.isNotEmpty) {
          buffer.writeln('  Parameters:');
          for (final param in action.parameters) {
            final req = param.required ? '(required)' : '(optional)';
            buffer.writeln('    - ${param.name} ${param.type} $req');
          }
        }
      }
    }

    return buffer.toString();
  }

  /// Generate a tool definition for AI
  List<Map<String, dynamic>> generateToolDefinitions() {
    final tools = <Map<String, dynamic>>[];

    for (final playbook in enabledPlaybooks) {
      if (!playbook.isConfigured) continue;

      for (final action in playbook.actions) {
        final properties = <String, dynamic>{};
        final required = <String>[];

        for (final param in action.parameters) {
          properties[param.name] = {
            'type': _dartTypeToJsonType(param.type),
            'description': param.description ?? param.name,
          };
          if (param.required) {
            required.add(param.name);
          }
        }

        tools.add({
          'type': 'function',
          'function': {
            'name':
                '${playbook.name.toLowerCase().replaceAll(' ', '_')}_${action.name}',
            'description':
                '${playbook.name}: ${action.description ?? action.name}',
            'parameters': {
              'type': 'object',
              'properties': properties,
              'required': required,
            },
          },
          '_playbook_id': playbook.id,
          '_action_name': action.name,
        });
      }
    }

    return tools;
  }

  String _dartTypeToJsonType(String dartType) {
    switch (dartType.toLowerCase()) {
      case 'int':
      case 'double':
      case 'number':
        return 'number';
      case 'bool':
      case 'boolean':
        return 'boolean';
      case 'list':
      case 'array':
        return 'array';
      case 'map':
      case 'object':
        return 'object';
      default:
        return 'string';
    }
  }
}

/// A match between a query and a playbook trigger
class PlaybookMatch {
  final Playbook playbook;
  final PlaybookTrigger trigger;
  final double confidence;

  const PlaybookMatch({
    required this.playbook,
    required this.trigger,
    required this.confidence,
  });
}
