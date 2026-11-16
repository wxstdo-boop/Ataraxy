import 'package:flutter_test/flutter_test.dart';

import 'package:ataraxy/services/ai_service.dart';

void main() {
  group('AiService.keyFor', () {
    test('ships no bundled credential for the ADA endpoint', () {
      // Regression guard: ADA used to carry a split HuggingFace token in the
      // binary. With no user key configured the endpoint must resolve to null
      // so the chat falls through to the free providers.
      expect(AiService.keyFor(AiService.adaEndpoint, null), isNull);
      expect(AiService.keyFor(AiService.adaEndpoint, ''), isNull);
    });

    test('ADA only accepts a user-pasted hf_ key', () {
      expect(AiService.keyFor(AiService.adaEndpoint, 'hf_secret'), 'hf_secret');
      expect(AiService.keyFor(AiService.adaEndpoint, 'sk-not-hf'), isNull);
    });

    test('the free endpoint needs no key but forwards one when given', () {
      expect(AiService.keyFor(AiService.defaultEndpoint, null), isNull);
      expect(AiService.keyFor(AiService.defaultEndpoint, 'abc'), 'abc');
    });
  });

  group('AiService.providerForKey', () {
    test('maps known key prefixes to their provider', () {
      expect(AiService.providerForKey('hf_x').label, 'HuggingFace');
      expect(AiService.providerForKey('gsk_x').label, 'Groq');
      expect(AiService.providerForKey('AIza_x').label, 'Gemini');
      expect(AiService.providerForKey('sk-or-x').label, 'OpenRouter');
      expect(AiService.providerForKey('csk_x').label, 'Cerebras');
    });

    test('falls back to Laguna for an unknown key', () {
      expect(AiService.providerForKey('totally-unknown').label, 'Laguna');
    });
  });
}
