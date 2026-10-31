import 'package:flutter_test/flutter_test.dart';
import 'package:docan/services/chat_service.dart';

void main() {
  group('ChatService.generateTitle', () {
    test('stores the first sentence in full, without an ellipsis', () {
      expect(
        ChatService.generateTitle(
          'Calculate the optimal voltage potential division cuircuit for '
          '36 dB reduction in the output of an amplifier. Maintain about '
          '100 ohm load on the amplifier output.',
        ),
        'Calculate the optimal voltage potential division cuircuit for '
        '36 dB reduction in the output of an amplifier.',
      );
    });

    test('keeps decimals and version numbers intact', () {
      expect(
        ChatService.generateTitle('Upgrade to v3.3.0 is out. What changed?'),
        'Upgrade to v3.3.0 is out.',
      );
    });

    test('uses the whole prompt when there is no sentence end', () {
      expect(ChatService.generateTitle('hello there'), 'hello there');
    });

    test('collapses newlines within the first sentence', () {
      expect(
        ChatService.generateTitle('line one\nstill same sentence. Next.'),
        'line one still same sentence.',
      );
    });

    test('empty prompt falls back to New Chat', () {
      expect(ChatService.generateTitle('   '), 'New Chat');
    });
  });
}
