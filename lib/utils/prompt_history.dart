import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class PromptHistory {
  PromptHistory({
    required this.controller,
    required this.promptsProvider,
  });

  final TextEditingController controller;
  final List<String> Function() promptsProvider;

  int? _index;
  String? _draft;

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final isUp = event.logicalKey == LogicalKeyboardKey.arrowUp;
    final isDown = event.logicalKey == LogicalKeyboardKey.arrowDown;
    if (!isUp && !isDown) return KeyEventResult.ignored;

    final text = controller.text;
    final selection = controller.selection;
    if (!selection.isCollapsed) return KeyEventResult.ignored;
    final offset = selection.baseOffset.clamp(0, text.length).toInt();

    if (isUp && !text.substring(0, offset).contains('\n')) {
      return back() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (isDown && !text.substring(offset).contains('\n')) {
      return forward() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  bool back() {
    final prompts = promptsProvider();
    if (prompts.isEmpty) return false;
    if (_index != null && _index == 0) return false;
    if (_index == null) {
      _draft = controller.text;
      _index = prompts.length - 1;
    } else {
      _index = _index! - 1;
    }
    _apply(prompts[_index!]);
    return true;
  }

  bool forward() {
    if (_index == null) return false;
    final prompts = promptsProvider();
    if (_index! >= prompts.length - 1) {
      _index = null;
      _apply(_draft ?? '');
    } else {
      _index = _index! + 1;
      _apply(prompts[_index!]);
    }
    return true;
  }

  void reset() {
    _index = null;
    _draft = null;
  }

  void _apply(String entry) {
    controller.text = entry;
    controller.selection = TextSelection.collapsed(offset: entry.length);
  }
}
