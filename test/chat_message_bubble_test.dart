import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docan/components/chat_message_bubble.dart';
import 'package:docan/models/chat_message.dart';

Widget _wrap(ChatMessage message) {
  return MaterialApp(
    home: Scaffold(
      body: ChatMessageBubble(message: message, maxWidth: 400),
    ),
  );
}

void main() {
  testWidgets('streaming assistant reply is hidden until content arrives',
      (tester) async {
    final waiting = ChatMessage(
      role: MessageRole.assistant,
      content: '  \n\n',
      isStreaming: true,
    );
    await tester.pumpWidget(_wrap(waiting));
    await tester.pumpAndSettle();
    expect(find.byType(Row), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final started = waiting.copyWith(content: 'First line of content');
    await tester.pumpWidget(_wrap(started));
    await tester.pumpAndSettle();
    expect(find.byType(Row), findsWidgets);
    expect(find.textContaining('First line of content'), findsWidgets);
  });

  testWidgets('streaming reply has no selection machinery; completed does',
      (tester) async {
    final streaming = ChatMessage(
      role: MessageRole.assistant,
      content: 'Live text',
      isStreaming: true,
    );
    await tester.pumpWidget(_wrap(streaming));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsNothing);
    expect(find.byType(SelectionArea), findsNothing);

    final done = streaming.copyWith(isStreaming: false);
    await tester.pumpWidget(_wrap(done));
    await tester.pumpAndSettle();
    expect(find.byType(SelectionArea), findsWidgets);
  });

  testWidgets('completed assistant message renders immediately',
      (tester) async {
    final done = ChatMessage(
      role: MessageRole.assistant,
      content: 'Complete response',
      isStreaming: false,
    );
    await tester.pumpWidget(_wrap(done));
    await tester.pumpAndSettle();
    expect(find.textContaining('Complete response'), findsWidgets);
  });

  testWidgets('user message renders immediately', (tester) async {
    final user = ChatMessage(
      role: MessageRole.user,
      content: 'My prompt',
    );
    await tester.pumpWidget(_wrap(user));
    await tester.pumpAndSettle();
    expect(find.textContaining('My prompt'), findsWidgets);
  });
}
