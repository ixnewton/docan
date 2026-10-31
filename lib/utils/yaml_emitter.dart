/// Emits plain Dart values (maps, lists, scalars) as YAML text.
///
/// The `yaml` package only parses; this minimal emitter covers the shapes
/// playbooks use: nested maps, lists of maps/scalars, strings, numbers,
/// booleans and nulls. Map keys are emitted in insertion order.
library;

String emitYaml(dynamic value, {int indent = 0}) {
  final buffer = StringBuffer();
  _emitNode(buffer, value, indent);
  return buffer.toString();
}

void _emitNode(StringBuffer buffer, dynamic value, int indent) {
  if (value is Map) {
    if (value.isEmpty) {
      buffer.write('{}\n');
      return;
    }
    _emitMapEntries(buffer, value, indent, firstInline: false);
  } else if (value is List) {
    if (value.isEmpty) {
      buffer.write('[]\n');
      return;
    }
    _emitList(buffer, value, indent);
  } else {
    buffer.write('${_scalar(value)}\n');
  }
}

/// Emits map entries at [indent]. When [firstInline] is true the first
/// entry continues an already-written prefix on the current line (e.g. "- ").
void _emitMapEntries(
  StringBuffer buffer,
  Map<dynamic, dynamic> map,
  int indent, {
  required bool firstInline,
}) {
  var first = true;
  map.forEach((key, value) {
    final inline = first && firstInline;
    first = false;
    if (!inline) {
      buffer.write(' ' * indent);
    }
    final hasNestedChildren =
        (value is Map && value.isNotEmpty) ||
        (value is List && value.isNotEmpty);
    if (hasNestedChildren) {
      buffer.write('${_scalar(key)}:\n');
      _emitNode(buffer, value, indent + 2);
    } else {
      buffer.write('${_scalar(key)}: ${_scalar(value)}\n');
    }
  });
}

void _emitList(StringBuffer buffer, List<dynamic> list, int indent) {
  for (final item in list) {
    buffer.write(' ' * indent);
    if (item is Map && item.isNotEmpty) {
      buffer.write('- ');
      _emitMapEntries(buffer, item, indent + 2, firstInline: true);
    } else if (item is List && item.isNotEmpty) {
      buffer.write('-\n');
      _emitList(buffer, item, indent + 2);
    } else {
      buffer.write('- ${_scalar(item)}\n');
    }
  }
}

String _scalar(dynamic value) {
  if (value == null) return 'null';
  if (value is bool) return value.toString();
  if (value is num) return value.toString();
  final s = value.toString();
  if (s.isEmpty) return "''";
  if (s.contains('\n')) {
    final quoted = s
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n');
    return '"$quoted"';
  }
  final needsQuotes = _needsQuotesPattern.hasMatch(s) ||
      s.endsWith(' ') ||
      s == 'true' ||
      s == 'false' ||
      s == 'null' ||
      double.tryParse(s) != null;
  if (needsQuotes) {
    final quoted = s
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"');
    return '"$quoted"';
  }
  return s;
}

final RegExp _needsQuotesPattern = RegExp(
  "[ :#{}\\[\\],&*?|>'\"%@`]|^\\s|\\s:\$",
);
