import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docan/components/streaming_markdown.dart';

Widget _wrap(String data) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: StreamingMarkdown(data: data, textColor: Colors.black87),
      ),
    ),
  );
}

void main() {
  group('StreamingMarkdown.splitBlocks', () {
    test('splits paragraphs at blank lines', () {
      final blocks = StreamingMarkdown.splitBlocks('one\ntwo\n\nthree');
      expect(blocks, ['one\ntwo\n', 'three\n']);
    });

    test('keeps fenced code blocks intact across blank lines', () {
      const text = 'para\n\n```\ncode line\n\nmore code\n```\n\nafter';
      final blocks = StreamingMarkdown.splitBlocks(text);
      expect(blocks.length, 3);
      expect(blocks[1], contains('code line'));
      expect(blocks[1], contains('more code'));
      expect(blocks[1], contains('```'));
    });

    test('unclosed fence keeps remainder in one block', () {
      const text = 'para\n\n```dart\nvoid main() {}\n';
      final blocks = StreamingMarkdown.splitBlocks(text);
      expect(blocks.length, 2);
      expect(blocks[1], startsWith('```dart'));
    });

    test('empty text yields no blocks', () {
      expect(StreamingMarkdown.splitBlocks(''), isEmpty);
    });

    test('text ending with a blank line yields no extra tail', () {
      expect(StreamingMarkdown.splitBlocks('para\n\n'), ['para\n']);
    });

    test('table block stays intact while rows arrive', () {
      const text = 'Intro\n\n| A | B |\n|---|---|\n| 1 | 2 |';
      final blocks = StreamingMarkdown.splitBlocks(text);
      expect(blocks.length, 2);
      expect(blocks[1], contains('| A | B |'));
      expect(blocks[1], contains('| 1 | 2 |'));
    });
  });

  group('StreamingMarkdown widget', () {
    testWidgets('renders a completed table as a table', (tester) async {
      const partial = 'Intro\n\n| A | B |\n|---|---|\n| 1 | 2 |\n';
      await tester.pumpWidget(_wrap(partial));
      expect(find.byType(Table), findsOneWidget);
      expect(
        tester.widget<Table>(find.byType(Table)).children.length,
        greaterThanOrEqualTo(2),
      );
    });

    testWidgets('grows the table as new rows arrive', (tester) async {
      const d1 = 'Intro\n\n| A | B |\n|---|---|\n| 1 | 2 |\n';
      await tester.pumpWidget(_wrap(d1));
      final rowsBefore =
          tester.widget<Table>(find.byType(Table)).children.length;

      const d2 = 'Intro\n\n| A | B |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |\n';
      await tester.pumpWidget(_wrap(d2));
      final rowsAfter =
          tester.widget<Table>(find.byType(Table)).children.length;
      expect(rowsAfter, greaterThan(rowsBefore));
    });

    testWidgets('stable blocks are memoized across updates', (tester) async {
      const d1 = 'para one\n\n| A | B |\n|---|---|\n| 1 | 2 |\n';
      await tester.pumpWidget(_wrap(d1));
      final elementBefore = tester.element(find.byKey(const ValueKey('sm-block-0')));

      const d2 =
          'para one\n\n| A | B |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |\n\nafter table';
      await tester.pumpWidget(_wrap(d2));
      final elementAfter = tester.element(find.byKey(const ValueKey('sm-block-0')));

      expect(identical(elementBefore, elementAfter), isTrue);
      expect(find.textContaining('after table'), findsWidgets);
    });

    testWidgets('renders complete message with mixed blocks', (tester) async {
      const full =
          '# Title\n\nPara **bold**\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\n- item one\n- item two\n';
      await tester.pumpWidget(_wrap(full));
      expect(find.byType(Table), findsOneWidget);
      expect(find.textContaining('Title'), findsWidgets);
      expect(find.textContaining('item one'), findsWidgets);
      expect(find.textContaining('item two'), findsWidgets);
    });

    testWidgets('renders empty data without error', (tester) async {
      await tester.pumpWidget(_wrap(''));
      expect(find.byType(Table), findsNothing);
    });

    testWidgets('renders whitespace-only data as nothing', (tester) async {
      await tester.pumpWidget(_wrap('\n\n   \n'));
      expect(find.byType(Column), findsNothing);
      expect(find.byType(Table), findsNothing);
    });
  });
}
