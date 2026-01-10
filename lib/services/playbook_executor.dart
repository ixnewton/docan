import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/playbook.dart';

/// Executor for running playbook actions
class PlaybookExecutor {
  final Map<String, dynamic> _globalContext = {};

  /// Execute a playbook action
  Future<PlaybookResult> execute({
    required Playbook playbook,
    required PlaybookAction action,
    required Map<String, dynamic> parameters,
    Map<String, dynamic>? context,
  }) async {
    final execContext = ExecutionContext(
      playbook: playbook,
      action: action,
      parameters: parameters,
      variables: {
        'config': playbook.userConfig,
        'params': parameters,
        ...?context,
        ..._globalContext,
      },
    );

    try {
      // Validate required parameters
      for (final param in action.parameters) {
        if (param.required && !parameters.containsKey(param.name)) {
          return PlaybookResult.failure(
            'Missing required parameter: ${param.name}',
          );
        }
      }

      // Execute each step
      dynamic lastResult;
      for (final step in action.steps) {
        final result = await _executeStep(step, execContext);
        if (!result.success) {
          return result;
        }
        lastResult = result.data;
      }

      // Return the last step's result
      // Note: action.returns is just metadata (type/description), not the actual data
      return PlaybookResult.success(
        data: lastResult,
        context: execContext.variables,
      );
    } catch (e, stack) {
      debugPrint('[PlaybookExecutor] Error executing action: $e\n$stack');
      return PlaybookResult.failure('Execution error: $e');
    }
  }

  Future<PlaybookResult> _executeStep(
    PlaybookStep step,
    ExecutionContext context,
  ) async {
    switch (step.type) {
      case StepType.http:
        return _executeHttp(step, context);
      case StepType.webhook:
        return _executeWebhook(step, context);
      case StepType.transform:
        return _executeTransform(step, context);
      case StepType.condition:
        return _executeCondition(step, context);
      case StepType.loop:
        return _executeLoop(step, context);
      case StepType.setVariable:
        return _executeSetVariable(step, context);
      case StepType.returnData:
        return _executeReturn(step, context);
      case StepType.askUser:
        return _executeAskUser(step, context);
      case StepType.askAI:
        return _executeAskAI(step, context);
    }
  }

  /// Execute HTTP request step
  Future<PlaybookResult> _executeHttp(
    PlaybookStep step,
    ExecutionContext context,
  ) async {
    try {
      final config = step.config;

      // Process URL with template
      final urlStr = _resolveTemplate(config['url']?.toString() ?? '', context);

      // Process headers
      final headers = <String, String>{};
      final headersConfig = config['headers'] as Map<String, dynamic>?;
      headersConfig?.forEach((key, value) {
        headers[key] = _resolveTemplate(value.toString(), context);
      });

      // Process query parameters
      final queryParams = <String, String>{};
      final paramsConfig = config['params'] as Map<String, dynamic>?;
      paramsConfig?.forEach((key, value) {
        queryParams[key] = _resolveTemplate(value.toString(), context);
      });

      // Build URL with query params
      var url = Uri.parse(urlStr);
      if (queryParams.isNotEmpty) {
        url = url.replace(
          queryParameters: {...url.queryParameters, ...queryParams},
        );
      }

      // Process body
      dynamic body;
      final bodyConfig = config['body'];
      if (bodyConfig != null) {
        if (bodyConfig is String) {
          body = _resolveTemplate(bodyConfig, context);
        } else {
          body = jsonEncode(_processTemplate(bodyConfig, context));
          headers['Content-Type'] ??= 'application/json';
        }
      }

      // Determine method
      final methodStr = config['method']?.toString().toUpperCase() ?? 'GET';

      debugPrint('[PlaybookExecutor] HTTP $methodStr $url');

      // Execute request
      http.Response response;
      switch (methodStr) {
        case 'POST':
          response = await http.post(url, headers: headers, body: body);
          break;
        case 'PUT':
          response = await http.put(url, headers: headers, body: body);
          break;
        case 'PATCH':
          response = await http.patch(url, headers: headers, body: body);
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers);
          break;
        default:
          response = await http.get(url, headers: headers);
      }

      debugPrint('[PlaybookExecutor] Response: ${response.statusCode}');

      // Parse response
      dynamic responseData;
      try {
        responseData = jsonDecode(response.body);
      } catch (e) {
        responseData = response.body;
      }

      // Check for error status
      if (response.statusCode >= 400) {
        return PlaybookResult.failure(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          context: {'response': responseData},
        );
      }

      // Store response if configured
      final storeName = config['response']?['store']?.toString();
      if (storeName != null) {
        context.variables[storeName] = responseData;
      }

      return PlaybookResult.success(data: responseData);
    } catch (e) {
      return PlaybookResult.failure('HTTP request failed: $e');
    }
  }

  /// Execute webhook step
  Future<PlaybookResult> _executeWebhook(
    PlaybookStep step,
    ExecutionContext context,
  ) async {
    // Similar to HTTP but specifically for webhooks
    final config = step.config;
    final url = _resolveTemplate(config['url']?.toString() ?? '', context);

    final payload = _processTemplate(config['payload'] ?? {}, context);

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 400) {
        return PlaybookResult.failure('Webhook failed: ${response.statusCode}');
      }

      return PlaybookResult.success(data: {'sent': true});
    } catch (e) {
      return PlaybookResult.failure('Webhook failed: $e');
    }
  }

  /// Execute transform step
  Future<PlaybookResult> _executeTransform(
    PlaybookStep step,
    ExecutionContext context,
  ) async {
    final config = step.config;

    // Get input data
    final inputPath = config['input']?.toString() ?? '';
    final input = _resolveValue(inputPath, context);

    // Get output variable name
    final outputName = config['output']?.toString() ?? 'result';

    // Apply transformation
    final mapConfig = config['map'] as Map<String, dynamic>?;
    final filterConfig = config['filter']?.toString();

    dynamic result = input;

    // Filter
    if (filterConfig != null && result is List) {
      result = result.where((item) {
        context.variables['item'] = item;
        return _evaluateCondition(filterConfig, context);
      }).toList();
    }

    // Map
    if (mapConfig != null && result is List) {
      result = result.map((item) {
        context.variables['item'] = item;
        return _processTemplate(mapConfig, context);
      }).toList();
    } else if (mapConfig != null) {
      context.variables['item'] = result;
      result = _processTemplate(mapConfig, context);
    }

    context.variables[outputName] = result;

    return PlaybookResult.success(data: result);
  }

  /// Execute condition step
  Future<PlaybookResult> _executeCondition(
    PlaybookStep step,
    ExecutionContext context,
  ) async {
    final config = step.config;
    final condition = config['if']?.toString() ?? 'true';

    if (_evaluateCondition(condition, context)) {
      final thenSteps = config['then'] as List?;
      if (thenSteps != null) {
        for (final stepConfig in thenSteps) {
          final step = PlaybookStep.fromJson(stepConfig);
          final result = await _executeStep(step, context);
          if (!result.success) return result;
        }
      }
    } else {
      final elseSteps = config['else'] as List?;
      if (elseSteps != null) {
        for (final stepConfig in elseSteps) {
          final step = PlaybookStep.fromJson(stepConfig);
          final result = await _executeStep(step, context);
          if (!result.success) return result;
        }
      }
    }

    return PlaybookResult.success();
  }

  /// Execute loop step
  Future<PlaybookResult> _executeLoop(
    PlaybookStep step,
    ExecutionContext context,
  ) async {
    final config = step.config;
    final itemsPath = config['items']?.toString() ?? '';
    final items = _resolveValue(itemsPath, context);

    if (items is! List) {
      return PlaybookResult.failure('Loop items must be a list');
    }

    final itemName = config['as']?.toString() ?? 'item';
    final loopSteps = config['steps'] as List?;

    final results = <dynamic>[];

    for (var i = 0; i < items.length; i++) {
      context.variables[itemName] = items[i];
      context.variables['index'] = i;

      if (loopSteps != null) {
        for (final stepConfig in loopSteps) {
          final step = PlaybookStep.fromJson(stepConfig);
          final result = await _executeStep(step, context);
          if (!result.success) return result;
          results.add(result.data);
        }
      }
    }

    return PlaybookResult.success(data: results);
  }

  /// Execute set variable step
  Future<PlaybookResult> _executeSetVariable(
    PlaybookStep step,
    ExecutionContext context,
  ) async {
    final config = step.config;
    final name = config['name']?.toString() ?? 'var';
    final value = config['value'];

    context.variables[name] = _processTemplate(value, context);

    return PlaybookResult.success(data: context.variables[name]);
  }

  /// Execute return step
  Future<PlaybookResult> _executeReturn(
    PlaybookStep step,
    ExecutionContext context,
  ) async {
    final config = step.config;
    final data = _processTemplate(config['data'] ?? config['value'], context);
    final message = config['message']?.toString();

    return PlaybookResult.success(
      data: data,
      message: message != null ? _resolveTemplate(message, context) : null,
    );
  }

  /// Execute ask user step (returns a request for user input)
  Future<PlaybookResult> _executeAskUser(
    PlaybookStep step,
    ExecutionContext context,
  ) async {
    final config = step.config;
    final question = _resolveTemplate(
      config['question']?.toString() ?? '',
      context,
    );
    final options = (config['options'] as List?)
        ?.map((e) => e.toString())
        .toList();

    return PlaybookResult.success(
      data: {'type': 'ask_user', 'question': question, 'options': options},
    );
  }

  /// Execute ask AI step (request AI to process something)
  Future<PlaybookResult> _executeAskAI(
    PlaybookStep step,
    ExecutionContext context,
  ) async {
    final config = step.config;
    final prompt = _resolveTemplate(
      config['prompt']?.toString() ?? '',
      context,
    );
    final data = _processTemplate(config['data'], context);

    return PlaybookResult.success(
      data: {'type': 'ask_ai', 'prompt': prompt, 'data': data},
    );
  }

  /// Resolve a template string with variable substitution
  String _resolveTemplate(String template, ExecutionContext context) {
    return template.replaceAllMapped(RegExp(r'\{\{([^}]+)\}\}'), (match) {
      final path = match.group(1)?.trim() ?? '';
      final value = _resolveValue(path, context);
      return value?.toString() ?? '';
    });
  }

  /// Process a template object recursively
  dynamic _processTemplate(dynamic template, ExecutionContext context) {
    if (template == null) return null;

    if (template is String) {
      // Check if it's a template reference
      if (template.startsWith('{{') && template.endsWith('}}')) {
        final path = template.substring(2, template.length - 2).trim();
        return _resolveValue(path, context);
      }
      return _resolveTemplate(template, context);
    }

    if (template is Map) {
      final result = <String, dynamic>{};
      template.forEach((key, value) {
        result[key.toString()] = _processTemplate(value, context);
      });
      return result;
    }

    if (template is List) {
      return template.map((e) => _processTemplate(e, context)).toList();
    }

    return template;
  }

  /// Resolve a dot-notation path to a value
  dynamic _resolveValue(String path, ExecutionContext context) {
    if (path.isEmpty) return null;

    final parts = _parsePath(path);
    dynamic current = context.variables;

    for (final part in parts) {
      if (current == null) return null;

      if (part.startsWith('[') && part.endsWith(']')) {
        // Array index
        final index = int.tryParse(part.substring(1, part.length - 1));
        if (index != null && current is List && index < current.length) {
          current = current[index];
        } else {
          return null;
        }
      } else if (current is Map) {
        current = current[part];
      } else {
        return null;
      }
    }

    return current;
  }

  /// Parse a path like "items[0].name" into parts
  List<String> _parsePath(String path) {
    final parts = <String>[];
    final regex = RegExp(r'(\w+)|\[(\d+)\]');

    for (final match in regex.allMatches(path)) {
      if (match.group(1) != null) {
        parts.add(match.group(1)!);
      } else if (match.group(2) != null) {
        parts.add('[${match.group(2)}]');
      }
    }

    return parts;
  }

  /// Evaluate a simple condition expression
  bool _evaluateCondition(String condition, ExecutionContext context) {
    // Simple evaluation - can be extended
    final resolved = _resolveTemplate(condition, context);

    if (resolved == 'true') return true;
    if (resolved == 'false') return false;
    if (resolved.isEmpty) return false;

    // Try to evaluate comparison operators
    final comparisonMatch = RegExp(
      r'(.+?)\s*(==|!=|>=|<=|>|<)\s*(.+)',
    ).firstMatch(resolved);
    if (comparisonMatch != null) {
      final left = comparisonMatch.group(1)?.trim();
      final op = comparisonMatch.group(2);
      final right = comparisonMatch.group(3)?.trim();

      switch (op) {
        case '==':
          return left == right;
        case '!=':
          return left != right;
        case '>':
          return (double.tryParse(left ?? '') ?? 0) >
              (double.tryParse(right ?? '') ?? 0);
        case '<':
          return (double.tryParse(left ?? '') ?? 0) <
              (double.tryParse(right ?? '') ?? 0);
        case '>=':
          return (double.tryParse(left ?? '') ?? 0) >=
              (double.tryParse(right ?? '') ?? 0);
        case '<=':
          return (double.tryParse(left ?? '') ?? 0) <=
              (double.tryParse(right ?? '') ?? 0);
      }
    }

    return resolved.isNotEmpty && resolved != 'null' && resolved != '0';
  }

  /// Set a global context variable
  void setGlobalVariable(String name, dynamic value) {
    _globalContext[name] = value;
  }

  /// Clear global context
  void clearGlobalContext() {
    _globalContext.clear();
  }
}

/// Context for playbook execution
class ExecutionContext {
  final Playbook playbook;
  final PlaybookAction action;
  final Map<String, dynamic> parameters;
  final Map<String, dynamic> variables;

  ExecutionContext({
    required this.playbook,
    required this.action,
    required this.parameters,
    Map<String, dynamic>? variables,
  }) : variables = variables ?? {};
}
