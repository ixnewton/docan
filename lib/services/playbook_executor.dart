import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/playbook.dart';

/// Status of a playbook execution step
enum PlaybookStepStatus { pending, running, success, failed, skipped }

/// Progress update during playbook execution
class PlaybookProgress {
  final int currentStep;
  final int totalSteps;
  final String stepName;
  final PlaybookStepStatus status;
  final String? message;
  final dynamic data;

  const PlaybookProgress({
    required this.currentStep,
    required this.totalSteps,
    required this.stepName,
    required this.status,
    this.message,
    this.data,
  });

  double get progress => totalSteps > 0 ? currentStep / totalSteps : 0;
  bool get isComplete => currentStep >= totalSteps;
}

/// Validation error for playbook parameters
class ValidationError {
  final String field;
  final String message;
  final dynamic expected;
  final dynamic actual;

  const ValidationError({
    required this.field,
    required this.message,
    this.expected,
    this.actual,
  });

  @override
  String toString() => '$field: $message';
}

/// Result of dry run check
class DryRunResult {
  final bool canRun;
  final List<String> issues;
  final List<String> warnings;

  const DryRunResult({
    required this.canRun,
    this.issues = const [],
    this.warnings = const [],
  });
}

/// Executor for running playbook actions
class PlaybookExecutor {
  final Map<String, dynamic> _globalContext = {};

  /// Execute a playbook action (returns final result)
  Future<PlaybookResult> execute({
    required Playbook playbook,
    required PlaybookAction action,
    required Map<String, dynamic> parameters,
    Map<String, dynamic>? context,
  }) async {
    PlaybookResult? lastResult;

    await for (final progress in executeStream(
      playbook: playbook,
      action: action,
      parameters: parameters,
      context: context,
    )) {
      if (progress.data is PlaybookResult) {
        lastResult = progress.data as PlaybookResult;
      }
    }

    return lastResult ?? PlaybookResult.failure('No result from execution');
  }

  /// Execute a playbook action with progress stream
  Stream<PlaybookProgress> executeStream({
    required Playbook playbook,
    required PlaybookAction action,
    required Map<String, dynamic> parameters,
    Map<String, dynamic>? context,
  }) async* {
    // Apply default values for parameters that weren't provided
    final effectiveParams = _applyParameterDefaults(action, parameters);
    
    final execContext = ExecutionContext(
      playbook: playbook,
      action: action,
      parameters: effectiveParams,
      variables: {
        'config': playbook.userConfig,
        'params': effectiveParams,
        ...?context,
        ..._globalContext,
      },
    );

    final totalSteps = action.steps.length;

    // Validate parameters first
    yield PlaybookProgress(
      currentStep: 0,
      totalSteps: totalSteps,
      stepName: 'Validating parameters',
      status: PlaybookStepStatus.running,
    );

    final validationErrors = validateParameters(action, effectiveParams);
    if (validationErrors.isNotEmpty) {
      yield PlaybookProgress(
        currentStep: 0,
        totalSteps: totalSteps,
        stepName: 'Validation failed',
        status: PlaybookStepStatus.failed,
        message: validationErrors.map((e) => e.toString()).join(', '),
        data: PlaybookResult.failure(
          'Validation failed: ${validationErrors.map((e) => e.toString()).join(', ')}',
        ),
      );
      return;
    }

    // Execute each step
    dynamic lastResult;
    for (int i = 0; i < action.steps.length; i++) {
      final step = action.steps[i];
      final stepName = _getStepName(step, i);

      yield PlaybookProgress(
        currentStep: i,
        totalSteps: totalSteps,
        stepName: stepName,
        status: PlaybookStepStatus.running,
        message: 'Executing...',
      );

      try {
        final result = await _executeStepWithRetry(step, execContext);

        if (!result.success) {
          // Handle failure based on onFailure setting
          if (step.onFailure == 'continue') {
            yield PlaybookProgress(
              currentStep: i + 1,
              totalSteps: totalSteps,
              stepName: stepName,
              status: PlaybookStepStatus.skipped,
              message: 'Step failed but continuing: ${result.error}',
            );
            continue;
          } else if (step.onFailure == 'returnError') {
            yield PlaybookProgress(
              currentStep: i + 1,
              totalSteps: totalSteps,
              stepName: stepName,
              status: PlaybookStepStatus.failed,
              message: result.error,
              data: result,
            );
            return;
          } else {
            // 'throw' - stop execution
            yield PlaybookProgress(
              currentStep: i + 1,
              totalSteps: totalSteps,
              stepName: stepName,
              status: PlaybookStepStatus.failed,
              message: result.error,
              data: result,
            );
            return;
          }
        }

        lastResult = result.data;

        yield PlaybookProgress(
          currentStep: i + 1,
          totalSteps: totalSteps,
          stepName: stepName,
          status: PlaybookStepStatus.success,
          message: 'Completed',
        );
      } catch (e, stack) {
        debugPrint('[PlaybookExecutor] Error in step $i: $e\n$stack');

        if (step.onFailure == 'continue') {
          yield PlaybookProgress(
            currentStep: i + 1,
            totalSteps: totalSteps,
            stepName: stepName,
            status: PlaybookStepStatus.skipped,
            message: 'Exception but continuing: $e',
          );
          continue;
        }

        yield PlaybookProgress(
          currentStep: i + 1,
          totalSteps: totalSteps,
          stepName: stepName,
          status: PlaybookStepStatus.failed,
          message: 'Exception: $e',
          data: PlaybookResult.failure('Execution error: $e'),
        );
        return;
      }
    }

    // Final result
    yield PlaybookProgress(
      currentStep: totalSteps,
      totalSteps: totalSteps,
      stepName: 'Complete',
      status: PlaybookStepStatus.success,
      data: PlaybookResult.success(
        data: lastResult,
        context: execContext.variables,
      ),
    );
  }

  /// Validate parameters against action definition
  List<ValidationError> validateParameters(
    PlaybookAction action,
    Map<String, dynamic> parameters,
  ) {
    final errors = <ValidationError>[];

    for (final param in action.parameters) {
      final value = parameters[param.name];

      // Check required
      if (param.required &&
          (value == null || (value is String && value.isEmpty))) {
        errors.add(
          ValidationError(
            field: param.name,
            message: 'Required parameter is missing',
            expected: param.type,
            actual: null,
          ),
        );
        continue;
      }

      // Skip type check if value is null and not required
      if (value == null) continue;

      // Type validation
      final typeError = _validateType(param.name, value, param.type);
      if (typeError != null) {
        errors.add(typeError);
      }
    }

    return errors;
  }

  /// Apply default values for parameters that weren't provided
  Map<String, dynamic> _applyParameterDefaults(
    PlaybookAction action,
    Map<String, dynamic> parameters,
  ) {
    final result = Map<String, dynamic>.from(parameters);
    
    for (final param in action.parameters) {
      if (!result.containsKey(param.name) || result[param.name] == null) {
        if (param.defaultValue != null) {
          result[param.name] = param.defaultValue;
        }
      }
    }
    
    return result;
  }

  ValidationError? _validateType(
    String name,
    dynamic value,
    String expectedType,
  ) {
    switch (expectedType.toLowerCase()) {
      case 'string':
        if (value is! String) {
          return ValidationError(
            field: name,
            message: 'Expected string',
            expected: 'string',
            actual: value.runtimeType.toString(),
          );
        }
        break;
      case 'int':
      case 'integer':
        if (value is! int && int.tryParse(value.toString()) == null) {
          return ValidationError(
            field: name,
            message: 'Expected integer',
            expected: 'int',
            actual: value.runtimeType.toString(),
          );
        }
        break;
      case 'number':
      case 'double':
      case 'float':
        if (value is! num && double.tryParse(value.toString()) == null) {
          return ValidationError(
            field: name,
            message: 'Expected number',
            expected: 'number',
            actual: value.runtimeType.toString(),
          );
        }
        break;
      case 'bool':
      case 'boolean':
        if (value is! bool && value != 'true' && value != 'false') {
          return ValidationError(
            field: name,
            message: 'Expected boolean',
            expected: 'bool',
            actual: value.runtimeType.toString(),
          );
        }
        break;
      case 'array':
      case 'list':
        if (value is! List) {
          return ValidationError(
            field: name,
            message: 'Expected array',
            expected: 'array',
            actual: value.runtimeType.toString(),
          );
        }
        break;
      case 'object':
      case 'map':
        if (value is! Map) {
          return ValidationError(
            field: name,
            message: 'Expected object',
            expected: 'object',
            actual: value.runtimeType.toString(),
          );
        }
        break;
    }
    return null;
  }

  /// Check if a playbook can run (dry run)
  DryRunResult dryRun({
    required Playbook playbook,
    required PlaybookAction action,
    required Map<String, dynamic> parameters,
  }) {
    final issues = <String>[];
    final warnings = <String>[];
    
    // Apply defaults before validation
    final effectiveParams = _applyParameterDefaults(action, parameters);

    // Check if playbook is configured
    if (!playbook.isConfigured) {
      final missing = playbook.missingConfig.map((c) => c.name).join(', ');
      issues.add('Missing configuration: $missing');
    }

    // Validate parameters
    final validationErrors = validateParameters(action, effectiveParams);
    for (final error in validationErrors) {
      issues.add(error.toString());
    }

    // Check for template variables that might not be resolved
    for (final step in action.steps) {
      final configStr = jsonEncode(step.config);
      final templateRegex = RegExp(r'\{\{([^}]+)\}\}');
      for (final match in templateRegex.allMatches(configStr)) {
        final varName = match.group(1)?.trim().split('.').first;
        if (varName != null &&
            varName != 'config' &&
            varName != 'params' &&
            varName != 'item' &&
            !effectiveParams.containsKey(varName) &&
            !playbook.userConfig.containsKey(varName)) {
          warnings.add('Variable "$varName" may not be defined');
        }
      }
    }

    return DryRunResult(
      canRun: issues.isEmpty,
      issues: issues,
      warnings: warnings,
    );
  }

  String _getStepName(PlaybookStep step, int index) {
    switch (step.type) {
      case StepType.http:
        final method = step.config['method']?.toString().toUpperCase() ?? 'GET';
        final url = step.config['url']?.toString() ?? '';
        final shortUrl = url.length > 40 ? '${url.substring(0, 40)}...' : url;
        return '$method $shortUrl';
      case StepType.transform:
        return 'Transform data';
      case StepType.condition:
        return 'Check condition';
      case StepType.loop:
        return 'Loop over items';
      case StepType.setVariable:
        return 'Set variable';
      case StepType.returnData:
        return 'Return result';
      case StepType.webhook:
        return 'Send webhook';
      case StepType.askUser:
        return 'Ask user';
      case StepType.askAI:
        return 'Ask AI';
    }
  }

  /// Execute a step with retry logic
  Future<PlaybookResult> _executeStepWithRetry(
    PlaybookStep step,
    ExecutionContext context,
  ) async {
    int attempts = 0;
    PlaybookResult? lastResult;

    while (attempts <= step.retries) {
      if (attempts > 0) {
        debugPrint('[PlaybookExecutor] Retry attempt $attempts for step');
        await Future.delayed(Duration(milliseconds: step.retryDelayMs));
      }

      lastResult = await _executeStep(step, context);

      if (lastResult.success) {
        return lastResult;
      }

      attempts++;
    }

    return lastResult ??
        PlaybookResult.failure('Step failed after ${step.retries} retries');
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

      // Execute request with timeout
      final timeout = Duration(
        milliseconds: config['timeout'] as int? ?? 30000,
      );
      http.Response response;

      switch (methodStr) {
        case 'POST':
          response = await http
              .post(url, headers: headers, body: body)
              .timeout(timeout);
          break;
        case 'PUT':
          response = await http
              .put(url, headers: headers, body: body)
              .timeout(timeout);
          break;
        case 'PATCH':
          response = await http
              .patch(url, headers: headers, body: body)
              .timeout(timeout);
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers).timeout(timeout);
          break;
        default:
          response = await http.get(url, headers: headers).timeout(timeout);
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
          context: {
            'response': responseData,
            'statusCode': response.statusCode,
          },
        );
      }

      // Store response if configured
      final storeName = config['response']?['store']?.toString();
      if (storeName != null) {
        context.variables[storeName] = responseData;
      }

      return PlaybookResult.success(data: responseData);
    } on TimeoutException {
      return PlaybookResult.failure('HTTP request timed out');
    } catch (e) {
      return PlaybookResult.failure('HTTP request failed: $e');
    }
  }

  /// Execute webhook step
  Future<PlaybookResult> _executeWebhook(
    PlaybookStep step,
    ExecutionContext context,
  ) async {
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
          final nestedStep = PlaybookStep.fromJson(stepConfig);
          final result = await _executeStep(nestedStep, context);
          if (!result.success) return result;
        }
      }
    } else {
      final elseSteps = config['else'] as List?;
      if (elseSteps != null) {
        for (final stepConfig in elseSteps) {
          final nestedStep = PlaybookStep.fromJson(stepConfig);
          final result = await _executeStep(nestedStep, context);
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

    final results = <dynamic>[];
    final itemVar = config['as']?.toString() ?? 'item';
    final indexVar = config['index']?.toString() ?? 'index';

    for (int i = 0; i < items.length; i++) {
      context.variables[itemVar] = items[i];
      context.variables[indexVar] = i;

      final loopSteps = config['steps'] as List?;
      if (loopSteps != null) {
        for (final stepConfig in loopSteps) {
          final nestedStep = PlaybookStep.fromJson(stepConfig);
          final result = await _executeStep(nestedStep, context);
          if (!result.success) {
            // Check if we should break on error
            if (config['breakOnError'] == true) {
              return result;
            }
          }
          if (result.data != null) {
            results.add(result.data);
          }
        }
      }
    }

    // Store results if output is specified
    final outputName = config['output']?.toString();
    if (outputName != null) {
      context.variables[outputName] = results;
    }

    return PlaybookResult.success(data: results);
  }

  /// Execute set variable step
  Future<PlaybookResult> _executeSetVariable(
    PlaybookStep step,
    ExecutionContext context,
  ) async {
    final config = step.config;
    final name = config['name']?.toString() ?? '';
    final value = _resolveValue(config['value']?.toString() ?? '', context);

    context.variables[name] = value;
    return PlaybookResult.success(data: value);
  }

  /// Execute return step
  Future<PlaybookResult> _executeReturn(
    PlaybookStep step,
    ExecutionContext context,
  ) async {
    final config = step.config;
    // Support both 'data' and 'value' keys for returnData step
    final data = config['data'] ?? config['value'];
    final value = _processTemplate(data, context);
    return PlaybookResult.success(data: value);
  }

  /// Execute ask user step (placeholder)
  Future<PlaybookResult> _executeAskUser(
    PlaybookStep step,
    ExecutionContext context,
  ) async {
    // This would need UI integration
    return PlaybookResult.failure('askUser step requires UI integration');
  }

  /// Execute ask AI step (placeholder)
  Future<PlaybookResult> _executeAskAI(
    PlaybookStep step,
    ExecutionContext context,
  ) async {
    // This would need AI service integration
    return PlaybookResult.failure('askAI step requires AI service integration');
  }

  /// Resolve template variables in a string
  String _resolveTemplate(String template, ExecutionContext context) {
    return template.replaceAllMapped(RegExp(r'\{\{([^}]+)\}\}'), (match) {
      final path = match.group(1)?.trim() ?? '';
      final value = _resolveValue(path, context);
      return value?.toString() ?? '';
    });
  }

  /// Process template in complex objects
  dynamic _processTemplate(dynamic value, ExecutionContext context) {
    if (value is String) {
      return _resolveTemplate(value, context);
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k, _processTemplate(v, context)));
    } else if (value is List) {
      return value.map((v) => _processTemplate(v, context)).toList();
    }
    return value;
  }

  /// Resolve a value path like "config.apiKey" or "params.query"
  dynamic _resolveValue(String path, ExecutionContext context) {
    if (path.isEmpty) return null;

    // Check if it's a direct variable reference
    if (!path.contains('.') && !path.contains('[')) {
      return context.variables[path];
    }

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
