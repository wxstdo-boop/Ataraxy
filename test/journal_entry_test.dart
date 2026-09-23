import 'package:flutter_test/flutter_test.dart';
import 'package:ataraxy/models/entry.dart';

void main() {
  group('JournalEntry defensive fromJson', () {
    test('full entry round-trips through toJson/fromJson', () {
      final now = DateTime.now();
      final entry = JournalEntry(
        id: 'test-1',
        type: EntryType.dream,
        title: 'Lucid Dream',
        content: 'I flew over the city',
        createdAt: now,
        updatedAt: now,
        mood: 4,
        tags: ['lucid', 'flight'],
        isLucid: true,
        dreamSigns: ['flying', 'city'],
        category: EntryCategory.good,
      );

      final restored = JournalEntry.fromJson(entry.toJson());
      expect(restored.id, equals('test-1'));
      expect(restored.type, equals(EntryType.dream));
      expect(restored.title, equals('Lucid Dream'));
      expect(restored.content, equals('I flew over the city'));
      expect(restored.mood, equals(4));
      expect(restored.tags, equals(['lucid', 'flight']));
      expect(restored.isLucid, isTrue);
      expect(restored.dreamSigns, equals(['flying', 'city']));
      expect(restored.category, equals(EntryCategory.good));
    });

    test('missing id gets a generated fallback id', () {
      final entry = JournalEntry.fromJson({
        'type': 'dream',
        'title': 'No ID',
        'content': '...',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      expect(entry.id, startsWith('imported-'));
      expect(entry.title, equals('No ID'));
    });

    test('empty string id gets a generated fallback id', () {
      final entry = JournalEntry.fromJson({
        'id': '',
        'type': 'dream',
        'title': 'Empty ID',
        'content': '...',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      expect(entry.id, startsWith('imported-'));
    });

    test('null createdAt falls back to now', () {
      final entry = JournalEntry.fromJson({
        'id': 'test-null-date',
        'type': 'general',
        'title': 'No dates',
        'content': '...',
      });
      expect(entry.createdAt, isNotNull);
      // Allow ~1 second of clock drift
      expect(
        entry.createdAt.difference(DateTime.now()).inSeconds,
        lessThan(2),
      );
    });

    test('malformed createdAt integer fallback', () {
      final entry = JournalEntry.fromJson({
        'id': 'test-int-date',
        'type': 'general',
        'title': 'Int date',
        'content': '...',
        'createdAt': 1700000000000,
      });
      expect(entry.createdAt.year, equals(2023));
    });

    test('copyWith with type change clears dream-specific fields', () {
      final dream = JournalEntry(
        id: 'd1',
        type: EntryType.dream,
        title: 'Dream',
        content: '...',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isLucid: true,
        dreamSigns: ['water', 'dog'],
        forcingDuration: const Duration(minutes: 30),
        hrtTime: '08:00',
        hrtDosage: '2mg',
      );
      final general = dream.copyWith(type: EntryType.general);
      expect(general.isLucid, isNull);
      expect(general.dreamSigns, isEmpty);
      expect(general.forcingDuration, isNull);
      expect(general.hrtTime, isNull);
      expect(general.hrtDosage, isNull);
      // Water is life-specific too — cleared when type != life
      expect(general.waterLiters, isNull);
    });

    test('copyWith with life type change clears HRT fields', () {
      final entry = JournalEntry(
        id: 'l1',
        type: EntryType.life,
        title: 'Life',
        content: '...',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        waterLiters: 2.5,
        fastingStart: '08:00',
        fastingEnd: '16:00',
        hrtTime: '08:00',
        hrtDosage: '2mg',
      );
      final dream = entry.copyWith(type: EntryType.dream);
      expect(dream.waterLiters, isNull);
      expect(dream.fastingStart, isNull);
      expect(dream.fastingEnd, isNull);
      expect(dream.hrtTime, isNull);
      expect(dream.hrtDosage, isNull);
    });
  });
}
