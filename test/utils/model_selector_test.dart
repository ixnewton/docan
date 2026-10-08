import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docan/components/model_selector.dart';
import 'package:docan/models/ai_provider.dart';

void main() {
  const models = [
    'anthropic/claude-sonnet-5.5',
    'anthropic/claude-opus-5.5',
    'openai/gpt-5.5',
    'google/gemini-3.8-flash',
  ];

  Future<void> pumpSelector(
    WidgetTester tester, {
    required AIProvider provider,
    required String model,
    required ValueChanged<String> onModelChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ModelSelector(
              selectedProvider: provider,
              selectedModel: model,
              onProviderChanged: (_) {},
              onModelChanged: onModelChanged,
              fetchModels: (_) async => models,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('non-OpenRouter providers show two selectors, no vendor menu', (
    tester,
  ) async {
    await pumpSelector(
      tester,
      provider: AIProvider.openai,
      model: 'gpt-4o',
      onModelChanged: (_) {},
    );

    expect(find.byIcon(Icons.psychology), findsOneWidget); // provider
    expect(find.byIcon(Icons.category), findsNothing); // vendor
    expect(find.byIcon(Icons.memory), findsOneWidget); // model
  });

  testWidgets('OpenRouter shows the vendor selector with current vendor', (
    tester,
  ) async {
    await pumpSelector(
      tester,
      provider: AIProvider.openrouter,
      model: 'anthropic/claude-sonnet-5.5',
      onModelChanged: (_) {},
    );

    expect(find.byIcon(Icons.hub), findsOneWidget); // provider
    expect(find.byIcon(Icons.category), findsOneWidget); // vendor
    expect(find.byIcon(Icons.memory), findsOneWidget); // model
    expect(find.text('anthropic'), findsOneWidget); // current vendor label
    expect(find.text('claude-sonne...'), findsOneWidget); // truncated display
  });

  testWidgets('picking a vendor auto-selects its first model', (tester) async {
    String? picked;
    await pumpSelector(
      tester,
      provider: AIProvider.openrouter,
      model: 'anthropic/claude-sonnet-5.5',
      onModelChanged: (m) => picked = m,
    );

    await tester.tap(find.byIcon(Icons.category));
    await tester.pumpAndSettle();

    // All vendors listed
    expect(find.text('openai'), findsOneWidget);
    expect(find.text('google'), findsOneWidget);

    await tester.tap(find.text('openai'));
    await tester.pumpAndSettle();

    expect(picked, 'openai/gpt-5.5');
    expect(find.text('openai'), findsOneWidget); // vendor label updated
  });

  testWidgets('model menu is filtered to the selected vendor', (tester) async {
    await pumpSelector(
      tester,
      provider: AIProvider.openrouter,
      model: 'anthropic/claude-sonnet-5.5',
      onModelChanged: (_) {},
    );

    await tester.tap(find.byIcon(Icons.memory));
    await tester.pumpAndSettle();

    expect(
      find.text('anthropic/claude-sonnet-5.5'),
      findsOneWidget,
    ); // current model (full id in menu)
    expect(find.text('openai/gpt-5.5'), findsNothing); // other vendor filtered
    expect(find.text('google/gemini-3.8-flash'), findsNothing);
  });
}
