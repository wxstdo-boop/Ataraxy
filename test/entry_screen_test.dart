import 'package:flutter_test/flutter_test.dart';
import 'package:ataraxy/compat/material.dart';
import 'package:hive/hive.dart';

import 'package:ataraxy/models/entry.dart';
import 'package:ataraxy/screens/entry_screen.dart';

import 'helpers.dart';

/// Render-level tests for the entry editor.
///
/// Saving is deliberately not exercised here: the write is real Hive disk I/O
/// and the editor interleaves it with IME/autosave timers, which makes the
/// `runAsync` bookkeeping deadlock the test runner. Persistence is covered
/// directly in `storage_service_test.dart` instead.
void main() {
  setUpAll(() async {
    initTestStorage('entry');
  });

  setUp(() async {
    resetPrefs();
    if (Hive.isBoxOpen('journal_entries')) {
      await Hive.box('journal_entries').close();
    }
    await Hive.deleteBoxFromDisk('journal_entries');
  });

  /// Unmounts the editor and waits out its last-resort exit flush. Without
  /// this the flush write is still in flight when the next test closes the
  /// box, which deadlocks the runner.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
  }

  Future<void> pumpEntry(WidgetTester tester, {JournalEntry? entry}) async {
    addTearDown(() => unmount(tester));
    await tester.pumpWidget(testApp(EntryScreen(entry: entry)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('new entry shows the create title and empty fields',
      (tester) async {
    await pumpEntry(tester);

    expect(find.text('Новая запись'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Заголовок'), findsOneWidget);
  });

  testWidgets('editing an entry shows its title and prefilled text',
      (tester) async {
    final now = DateTime(2026, 2, 3, 9);
    final entry = JournalEntry(
      id: 'edit-1',
      type: EntryType.dream,
      title: 'Старый сон',
      content: 'Тело сна',
      createdAt: now,
      updatedAt: now,
    );
    await pumpEntry(tester, entry: entry);

    expect(find.text('Редактировать'), findsOneWidget);
    expect(find.text('Старый сон'), findsOneWidget);
  });

  testWidgets('content field grows and shrinks smoothly with its text',
      (tester) async {
    await pumpEntry(tester);

    final editor = find.byKey(const ValueKey('editor'));
    final animatedSize = find.byKey(const ValueKey('entry-content-size'));
    final initialHeight = tester.getSize(animatedSize).height;
    await tester.enterText(
      editor,
      List.generate(12, (i) => 'Строка ${i + 1}').join('\n'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final growingHeight = tester.getSize(animatedSize).height;
    await tester.pump(const Duration(milliseconds: 300));
    final expandedHeight = tester.getSize(animatedSize).height;

    expect(expandedHeight, greaterThan(initialHeight));
    expect(growingHeight, greaterThan(initialHeight));
    expect(growingHeight, lessThan(expandedHeight));

    await tester.enterText(editor, 'Одна строка');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final shrinkingHeight = tester.getSize(animatedSize).height;
    await tester.pump(const Duration(milliseconds: 300));
    final collapsedHeight = tester.getSize(animatedSize).height;

    expect(collapsedHeight, lessThan(expandedHeight));
    expect(shrinkingHeight, lessThan(expandedHeight));
    expect(shrinkingHeight, greaterThan(collapsedHeight));
  });

  testWidgets('switching entry type reveals the dream-only controls',
      (tester) async {
    await pumpEntry(tester);

    // A fresh note has no lucidity control; picking the dream type adds it.
    expect(find.text('Осознанный'), findsNothing);
    await tester.tap(find.text('Сон').first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Осознанный'), findsOneWidget);
  });
}
