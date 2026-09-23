import 'package:flutter_test/flutter_test.dart';
import 'package:ataraxy/models/entry.dart';

void main() {
  test('JournalEntry serialization', () {
    final entry = JournalEntry(
      id: 'test123',
      type: EntryType.dream,
      title: 'Test Dream',
      content: 'This is a test dream content',
      createdAt: DateTime(2026, 8, 18),
      updatedAt: DateTime(2026, 8, 18),
      mood: 3,
      tags: ['test', 'dream'],
      isLucid: true,
      category: EntryCategory.good,
    );

    final json = entry.toJson();
    expect(json['id'], 'test123');
    expect(json['type'], 'dream');
    expect(json['title'], 'Test Dream');
    expect(json['content'], 'This is a test dream content');
    expect(json['mood'], 3);
    expect(json['tags'], ['test', 'dream']);
    expect(json['isLucid'], true);
    expect(json['category'], 'good');
  });

  test('JournalEntry fromJson', () {
    final json = {
      'id': 'test123',
      'type': 'life',
      'title': 'Test Life',
      'content': 'This is a test life content',
      'createdAt': '2026-08-18T00:00:00.000',
      'updatedAt': '2026-08-18T00:00:00.000',
      'mood': 4,
      'tags': ['test', 'life'],
      'waterLiters': 1.5,
      'category': 'good',
    };

    final entry = JournalEntry.fromJson(json);
    expect(entry.id, 'test123');
    expect(entry.type, EntryType.life);
    expect(entry.title, 'Test Life');
    expect(entry.content, 'This is a test life content');
    expect(entry.mood, 4);
    expect(entry.tags, ['test', 'life']);
    expect(entry.waterLiters, 1.5);
    expect(entry.category, EntryCategory.good);
  });

  test('JournalEntry type conversion', () {
    expect(EntryTypeExtension(EntryType.dream).labelKey, 'typeDream');
    expect(EntryTypeExtension(EntryType.life).labelKey, 'typeLife');
    expect(EntryTypeExtension(EntryType.general).labelKey, 'typeGeneral');
    expect(EntryTypeExtension(EntryType.tulpa).labelKey, 'typeTulpa');
  });

  test('JournalEntry category conversion', () {
    expect(EntryCategoryExtension(EntryCategory.none).labelKey, 'catAll');
    expect(EntryCategoryExtension(EntryCategory.good).labelKey, 'catGood');
    expect(EntryCategoryExtension(EntryCategory.bad).labelKey, 'catBad');
    expect(EntryCategoryExtension(EntryCategory.random).labelKey, 'catRandom');
  });
}
