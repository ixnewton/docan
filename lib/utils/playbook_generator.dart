import '../services/ai_service.dart';

/// Generates playbook YAML from a natural-language description using the
/// configured AI provider, so the user starts from a valid skeleton.
class PlaybookGenerator {
  /// Sends a guided prompt to [service] and returns the generated playbook
  /// YAML. Throws with a readable message when the model does not return
  /// a usable YAML block.
  static Future<String> generateYaml(
    AIService service,
    String description,
  ) async {
    final response = await service.sendMessage(_prompt(description), []);
    return _extractYaml(response);
  }

  static String _prompt(String description) {
    return '''
You are generating a Docan playbook. Docan playbooks are YAML files that let a
chat assistant call real APIs. Produce ONE complete playbook based on this
request:

"$description"

Rules:
- Output exactly one fenced ```yaml code block and nothing else.
- Required top-level fields: name, version (e.g. "1.0.0"), playbookVersion: 1,
  description.
- Include config fields for anything the user must supply (API keys marked
  secret: true, with a description).
- Include triggers: a list of regex patterns matching how a user would
  naturally ask for this in chat (case-insensitive), each with a description.
- Include one or more actions. Each action has description, parameters
  (name/type/required/description — descriptions guide parameter
  extraction from the user's chat message) and a steps list.
- Only use these working step types: http (method, url, headers, params, body,
  timeout, response.store, retries, retryDelay, onFailure), webhook (url,
  payload), transform (input, output, filter, map), condition (if, then, else),
  loop (items, as, output, steps), setVariable (name, value), returnData
  (data, message). Do NOT use askUser or askAI — they are not implemented.
- End every action with a returnData step whose data is a structured object;
  the assistant renders that data in its reply.
- Use {{params.x}}, {{config.x}} and {{storedVariable}} templates.
- Prefer real public APIs for the request; use a placeholder URL only if the
  user's service is unknown.
''';
  }

  /// Extracts the ```yaml fenced block from the model response; falls back
  /// to the raw response when it already looks like a playbook.
  static String _extractYaml(String response) {
    final match = RegExp(
      r'```ya?ml\n(.*?)```',
      dotAll: true,
    ).firstMatch(response);
    final yaml = (match?.group(1) ?? response).trim();
    if (!RegExp(r'^name\s*:', multiLine: true).hasMatch(yaml)) {
      throw const FormatException(
        'The model did not return a usable playbook YAML block',
      );
    }
    return yaml;
  }
}
