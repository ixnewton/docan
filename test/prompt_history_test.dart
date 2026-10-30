import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docan/utils/prompt_history.dart';

(TextEditingController, PromptHistory) _make(
  List<String> prompts, {
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  final history = PromptHistory(
    controller: controller,
    promptsProvider: () => prompts,
  );
  addTearDown(controller.dispose);
  return (controller, history);
}

FocusNode _node() {
  final node = FocusNode();
  addTearDown(node.dispose);
  return node;
}

void main() {
  group('PromptHistory', () {
    test('back with empty history returns false and keeps text', () {
      final (controller, history) = _make([]);
      controller.text = 'draft';
      expect(history.back(), isFalse);
      expect(controller.text, 'draft');
    });

    test('back recalls newest prompt and saves draft', () {
      final (controller, history) = _make(['first', 'second']);
      controller.text = 'draft text';
      expect(history.back(), isTrue);
      expect(controller.text, 'second');
      expect(controller.selection.baseOffset, 'second'.length);
      expect(history.back(), isTrue);
      expect(controller.text, 'first');
      expect(history.back(), isFalse);
      expect(controller.text, 'first');
    });

    test('forward walks back to the draft', () {
      final (controller, history) = _make(['first', 'second'], initial: 'draft');
      history.back();
      history.back();
      expect(controller.text, 'first');
      expect(history.forward(), isTrue);
      expect(controller.text, 'second');
      expect(history.forward(), isTrue);
      expect(controller.text, 'draft');
      expect(history.forward(), isFalse);
    });

    test('forward without prior navigation returns false', () {
      final (controller, history) = _make(['a']);
      expect(history.forward(), isFalse);
      expect(controller.text, '');
    });

    test('editing a recalled entry then forward restores the draft', () {
      final (controller, history) = _make(['a', 'b'], initial: 'draft');
      history.back();
      controller.text = 'b edited';
      expect(history.forward(), isTrue);
      expect(controller.text, 'draft');
    });

    test('reset clears navigation state', () {
      final (controller, history) = _make(['a'], initial: 'draft');
      history.back();
      history.reset();
      expect(history.forward(), isFalse);
    });
  });

  group('PromptHistory.handleKeyEvent', () {
    test('up at first line recalls history', () {
      final (controller, history) = _make(['a', 'b']);
      final node = _node();
      controller.text = 'hello';
      controller.selection = const TextSelection.collapsed(offset: 2);
      final result = history.handleKeyEvent(
        node,
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowUp,
          logicalKey: LogicalKeyboardKey.arrowUp,
          character: null,
          timeStamp: Duration.zero,
        ),
      );
      expect(result, KeyEventResult.handled);
      expect(controller.text, 'b');
    });

    test('up mid-text is ignored so the cursor can move', () {
      final (controller, history) = _make(['a', 'b']);
      final node = _node();
      controller.text = 'line1\nline2';
      controller.selection = const TextSelection.collapsed(offset: 8);
      final result = history.handleKeyEvent(
        node,
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowUp,
          logicalKey: LogicalKeyboardKey.arrowUp,
          character: null,
          timeStamp: Duration.zero,
        ),
      );
      expect(result, KeyEventResult.ignored);
      expect(controller.text, 'line1\nline2');
    });

    test('down at last line walks forward during navigation', () {
      final (controller, history) = _make(['a', 'b']);
      final node = _node();
      controller.text = 'x';
      history.back();
      history.back();
      final result = history.handleKeyEvent(
        node,
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowDown,
          logicalKey: LogicalKeyboardKey.arrowDown,
          character: null,
          timeStamp: Duration.zero,
        ),
      );
      expect(result, KeyEventResult.handled);
      expect(controller.text, 'b');
    });

    test('down at last line while live is ignored', () {
      final (controller, history) = _make(['a']);
      final node = _node();
      controller.text = 'x';
      controller.selection = const TextSelection.collapsed(offset: 1);
      final result = history.handleKeyEvent(
        node,
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowDown,
          logicalKey: LogicalKeyboardKey.arrowDown,
          character: null,
          timeStamp: Duration.zero,
        ),
      );
      expect(result, KeyEventResult.ignored);
      expect(controller.text, 'x');
    });

    test('key-up events are ignored', () {
      final (controller, history) = _make(['a']);
      final node = _node();
      controller.text = 'x';
      final result = history.handleKeyEvent(
        node,
        KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.arrowUp,
          logicalKey: LogicalKeyboardKey.arrowUp,
          timeStamp: Duration.zero,
        ),
      );
      expect(result, KeyEventResult.ignored);
      expect(controller.text, 'x');
    });

    test('non-arrow keys are ignored', () {
      final (controller, history) = _make(['a']);
      final node = _node();
      controller.text = 'x';
      final result = history.handleKeyEvent(
        node,
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.keyA,
          character: 'a',
          timeStamp: Duration.zero,
        ),
      );
      expect(result, KeyEventResult.ignored);
      expect(controller.text, 'x');
    });
  });
}
