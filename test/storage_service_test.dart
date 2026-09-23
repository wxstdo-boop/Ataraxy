import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ataraxy/models/entry.dart';
import 'package:ataraxy/services/settings_service.dart';
import 'package:ataraxy/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService', () {
    setUpAll(() async {
      Hive.init(Directory.systemTemp.createTempSync('hive_storage').path);
    });
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // Hive caches open boxes: deleteBoxFromDisk throws if the box is
      // open, and skips nothing when it's closed — the old guard was
      // inverted, so entries leaked between tests. Always close first,
      // then delete regardless.
      if (Hive.isBoxOpen('journal_entries')) {
        await Hive.box('journal_entries').close();
      }
      await Hive.deleteBoxFromDisk('journal_entries');
    });
    tearDown(() async {
      if (Hive.isBoxOpen('journal_entries')) {
        await Hive.box('journal_entries').close();
      }
      await Hive.deleteBoxFromDisk('journal_entries');
    });
    test('importFromJson skips malformed entries gracefully', () async {
      final service = StorageService();
      final raw = '''
{
  "app": "Ataraxy",
  "version": 3,
  "entries": [
    {"id": "good-1", "type": "dream", "title": "Good", "content": "x", "createdAt": "2025-01-01T00:00:00.000", "updatedAt": "2025-01-01T00:00:00.000"},
    "not-an-object",
    {"type": "life", "title": "Missing required fields"}
  ],
  "favorites": [],
  "activities": []
}
''';
      final summary = await service.importFromJson(raw);
      expect(summary.entriesChanged, greaterThanOrEqualTo(0));
      expect(summary.entriesSkipped, greaterThanOrEqualTo(1));
    });

    test('importFromJson rejects non-object root', () {
      final service = StorageService();
      expect(
        () => service.importFromJson('"just a string"'),
        throwsException,
      );
    });

    test('importFromJson handles UTF-8 BOM', () async {
      final service = StorageService();
      final raw = '﻿{"app":"Ataraxy","version":3,"entries":[],"favorites":[],"activities":[]}';
      final summary = await service.importFromJson(raw);
      expect(summary, isNotNull);
    });

    test('migrates legacy SharedPreferences entries into the Hive box',
        () async {
      // Simulate an install that still has entries in the old storage.
      SharedPreferences.setMockInitialValues({
        'journal_entries': [
          jsonEncode({
            'id': 'legacy-1',
            'type': 'dream',
            'title': 'Migrated',
            'content': 'hello',
            'createdAt': '2025-01-01T00:00:00.000',
            'updatedAt': '2025-01-01T00:00:00.000',
          }),
        ],
      });

      final service = StorageService();
      final entries = await service.loadEntries();
      expect(entries, hasLength(1));
      expect(entries.first.title, 'Migrated');

      // The box now holds the data: a second load must NOT re-read prefs.
      SharedPreferences.setMockInitialValues({});
      final again = await service.loadEntries();
      expect(again, hasLength(1));
      expect(again.first.title, 'Migrated');
    });

    test('migrates the legacy Hive list key into per-entry keys', () async {
      final box = await Hive.openBox('journal_entries');
      await box.put('entries', [
        jsonEncode({
          'id': 'legacy-hive-1',
          'type': 'dream',
          'title': 'FromHiveList',
          'content': 'hi',
          'createdAt': '2025-01-01T00:00:00.000',
          'updatedAt': '2025-01-01T00:00:00.000',
        }),
      ]);

      final service = StorageService();
      final entries = await service.loadEntries();
      expect(entries, hasLength(1));
      expect(entries.first.title, 'FromHiveList');

      // Old list key is gone, data lives under entry_<id>.
      expect(box.get('entries'), isNull);
      expect(box.get('entry_legacy-hive-1'), isNotNull);
    });

    test('export → import round-trips entries, favorites and settings',
        () async {
      final service = StorageService();
      final entry = JournalEntry(
        id: 'rt-1',
        type: EntryType.dream,
        title: 'Круглый сон',
        content: '**жирный** текст и *курсив*',
        createdAt: DateTime(2025, 6, 1, 10),
        updatedAt: DateTime(2025, 6, 1, 10, 30),
        mood: 5,
        tags: const ['луна'],
      );
      await service.addEntry(entry);

      final json = await service.exportToJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['entries'], hasLength(1));
      expect(decoded['charset'], 'utf-8');

      // Wipe the box, then import the backup back.
      await Hive.deleteBoxFromDisk('journal_entries');
      final summary = await service.importFromJson(json);
      expect(summary.entriesChanged, 1);

      final loaded = await service.loadEntries();
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'rt-1');
      expect(loaded.single.title, 'Круглый сон');
      expect(loaded.single.content, '**жирный** текст и *курсив*');
      expect(loaded.single.mood, 5);
      expect(loaded.single.tags, ['луна']);
    });

    test('import with protection skips entries deleted on this device',
        () async {
      final service = StorageService();
      // Seed settings: protection ON.
      final settings = await SettingsService().load();
      await SettingsService().save(
        settings.copyWith(protectDeletedOnImport: true),
      );

      final entry = JournalEntry(
        id: 'zombie-1',
        type: EntryType.dream,
        title: 'Zombie',
        content: 'x',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
        mood: 3,
      );
      await service.addEntry(entry);
      await service.deleteEntry('zombie-1'); // creates the tombstone
      expect((await service.loadEntries()), isEmpty);

      // An old backup still contains the deleted entry.
      final json = jsonEncode({
        'app': 'Ataraxy',
        'version': 3,
        'entries': [entry.toJson()],
        'favorites': [],
        'activities': [],
      });
      final summary = await service.importFromJson(json);
      expect(summary.entriesChanged, 0);
      expect((await service.loadEntries()), isEmpty);
    });

    test('import without protection restores deleted entries (legacy merge)',
        () async {
      final service = StorageService();
      final settings = await SettingsService().load();
      await SettingsService().save(
        settings.copyWith(protectDeletedOnImport: false),
      );

      final entry = JournalEntry(
        id: 'zombie-2',
        type: EntryType.life,
        title: 'Back',
        content: 'y',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
        mood: 2,
      );
      await service.addEntry(entry);
      await service.deleteEntry('zombie-2');

      final json = jsonEncode({
        'app': 'Ataraxy',
        'version': 3,
        'entries': [entry.toJson()],
        'favorites': [],
        'activities': [],
      });
      final summary = await service.importFromJson(json);
      expect(summary.entriesChanged, 1);
      expect((await service.loadEntries()).length, 1);
    });

    test('add/update/delete operate per-entry without touching others',
        () async {
      final service = StorageService();
      final e1 = JournalEntry(
        id: 'a',
        type: EntryType.dream,
        title: 'A',
        content: 'x',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
        mood: 3,
      );
      final e2 = JournalEntry(
        id: 'b',
        type: EntryType.life,
        title: 'B',
        content: 'y',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025, 1, 2),
        mood: 4,
      );
      await service.addEntry(e1);
      await service.addEntry(e2);
      expect((await service.loadEntries()).length, 2);

      // Update only one entry.
      await service.updateEntry(e1.copyWith(title: 'A2'));
      final after = await service.loadEntries();
      expect(after.length, 2);
      expect(after.firstWhere((e) => e.id == 'a').title, 'A2');
      expect(after.firstWhere((e) => e.id == 'b').title, 'B');

      // Delete only one entry.
      await service.deleteEntry('a');
      final remaining = await service.loadEntries();
      expect(remaining.length, 1);
      expect(remaining.single.id, 'b');
    });

    test('export/import roundtrip', () async {
      final service = StorageService();
      final testEntry = JournalEntry(
        id: 'test_export',
        type: EntryType.dream,
        title: 'Export Test',
        content: 'This is a test for export/import',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mood: 5,
        tags: ['test', 'export'],
        category: EntryCategory.good,
      );
      await service.addEntry(testEntry);

      // Export to JSON
      final json = await service.exportToJson();
      expect(json, contains('test_export'));
      expect(json, contains('Export Test'));

      // Import into a fresh box and verify
      await service.importFromJson(json);
      final entries = await service.loadEntries();
      expect(entries.firstWhere((e) => e.id == 'test_export').title,
          'Export Test');
    });

    test('handles malformed JSON gracefully', () async {
      final service = StorageService();
      // importFromJson throws on a non-object top level / undecodable JSON.
      expect(() => service.importFromJson('{invalid json}'), throwsException);
    });
  });
}
