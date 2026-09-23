import 'package:flutter_test/flutter_test.dart';
import 'package:ataraxy/services/reply_cleaner.dart';

void main() {
  group('cleanReply (regression: FormatException Invalid group)', () {
    test('plain replies pass through untouched', () {
      final reply = cleanReply('Hello! How can I help you today?');
      expect(reply, 'Hello! How can I help you today?');
    });

    test('Russian dream-entry text with hyphen survives', () {
      final text = 'Сон про кошку - я её гладил, потом мы гуляли.';
      // Must NOT throw FormatException (the (?im) inline-flag bug).
      expect(() => cleanReply(text), returnsNormally);
      expect(cleanReply(text), text);
    });

    test('leading "Рассуждение:" preamble is stripped by cleanReply', () {
      final text = 'Рассуждение: сначала подумаем. \n\nОтвет: Привет!';
      final cleaned = cleanReply(text);
      expect(cleaned, 'Ответ: Привет!');
    });

    test('inline (лайф) markers are stripped', () {
      final text = 'Всё хорошо (лайф) — гуляли в парке (thinking)';
      expect(cleanReply(text), 'Всё хорошо — гуляли в парке');
    });

    test('JSON field-name artifact lines are dropped', () {
      final text = 'content: test\ntitle: x\nПривет мир';
      expect(cleanReply(text), 'Привет мир');
    });
  });

  group('stripReasoning (whole answers only)', () {
    test('no reasoning marker → text unchanged', () {
      const t = 'Привет! 2+2=4. Пока.';
      expect(stripReasoning(t), t);
    });

    test('English "Reasoning:" block with label is cut to the answer', () {
      const t = 'Reasoning: I need to compute this.\n\nAnswer: 2+2=4';
      expect(stripReasoning(t), '2+2=4');
    });

    test('Russian multiline "Рассуждение:" block is cut', () {
      const t =
          'Рассуждение:\nСначала подумаем о задаче.\nПотом решим.\n\n2+2=4. Вот ответ.';
      final out = stripReasoning(t);
      expect(out.contains('Рассуждение'), isFalse);
      expect(out.contains('подумаем'), isFalse);
      expect(out, contains('2+2=4'));
    });

    test('markdown **Reasoning:** header is stripped', () {
      const t = '**Reasoning:**\nsome thoughts\n\n**Answer:** Привет!';
      expect(stripReasoning(t), 'Привет!');
    });

    test('cleanReplyFull strips a full English thinking block', () {
      const t =
          'Thinking: The user asks a simple arithmetic question.\nI will answer directly.\n\n4';
      final out = cleanReplyFull(t);
      expect(out.contains('Thinking'), isFalse);
      expect(out.trim(), '4');
    });

    test('reasoning-only reply becomes empty (caller falls back)', () {
      const t = 'Рассуждение:\nразмышляю и ничего не отвечаю';
      expect(cleanReplyFull(t).trim(), isEmpty);
    });

    test('English self-talk WITHOUT a marker is cut (Horde gemma)', () {
      // Horde's gemma pastes its chain-of-thought as plain English prose
      // with no "Reasoning:" label — the real reply comes last.
      const t = 'The user is asking in Russian: "tell me something '
          'interesting". I need to respond as ADA, warm and witty. Should I '
          'create a journal entry? No, just respond.\n\nLet me craft a '
          'response. Maybe share a psychological fact.\n\nО, с удовольствием! '
          'Знаешь ли ты, что мозг запоминает яркие сны лучше обычных мыслей?';
      final out = cleanReplyFull(t);
      expect(out.contains('The user'), isFalse);
      expect(out.contains('I need to'), isFalse);
      expect(out, contains('О, с удовольствием'));
    });

    test('single-paragraph English self-talk stays (no answer to cut to)', () {
      const t = 'The user is asking a question. I should answer it politely.';
      expect(cleanReplyFull(t), t);
    });
  });
}
