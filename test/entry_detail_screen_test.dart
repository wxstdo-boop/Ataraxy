import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:ataraxy/compat/material.dart';
import 'package:hive/hive.dart';

import 'package:ataraxy/models/entry.dart';
import 'package:ataraxy/screens/entry_detail_screen.dart';
import 'package:ataraxy/services/storage_service.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => initTestStorage('entry_detail'));

  setUp(() async {
    resetPrefs();
    if (Hive.isBoxOpen('journal_entries')) {
      await Hive.box('journal_entries').close();
    }
    await Hive.deleteBoxFromDisk('journal_entries');
  });

  testWidgets('entry content cannot be selected in read mode', (tester) async {
    final now = DateTime(2026, 11, 15, 10);
    final entry = JournalEntry(
      id: 'read-only-content',
      type: EntryType.dream,
      title: 'Запись',
      content: 'Первый абзац\n\nВторой абзац',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      testApp(EntryDetailScreen(entry: entry, storage: StorageService())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(
      tester.widget<MarkdownBody>(find.byType(MarkdownBody)).selectable,
      isFalse,
    );
    expect(find.byKey(const ValueKey('entry-content-size')), findsOneWidget);
  });
}
