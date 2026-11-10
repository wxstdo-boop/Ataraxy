
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ataraxy/models/entry.dart';
import 'package:ataraxy/screens/home_screen.dart';
import 'package:ataraxy/services/storage_service.dart';

import 'helpers.dart';

void main() {
  setUpAll(() async {
    initTestStorage('home');
  });

  setUp(() async {
    resetPrefs();
    if (Hive.isBoxOpen('journal_entries')) {
      await Hive.box('journal_entries').close();
    }
    await Hive.deleteBoxFromDisk('journal_entries');
  });

  tearDown(() async {
    if (Hive.isBoxOpen('journal_entries')) {
      await Hive.box('journal_entries').close();
    }
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    List<JournalEntry> entries = const [],
    bool tulpaEnabled = false,
  }) async {
    if (entries.isNotEmpty) {
      await tester.runAsync(() => StorageService().saveEntries(entries));
    }
    // HomeScreen loads entries through Hive, which does real (async) file
    // I/O — that never completes under the fake async clock, so the screen
    // would stay stuck on its skeleton. runAsync lets the I/O settle, then a
    // couple of pumps flush the resulting setState.
    await tester.runAsync(() async {
      await tester.pumpWidget(testApp(HomeScreen(tulpaEnabled: tulpaEnabled)));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('renders the header wordmark and the default tabs',
      (tester) async {
    await pumpHome(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    // Brand wordmark in the header.
    expect(find.text('Ataraxy'), findsWidgets);
    // Tab labels come from L.tr for the active locale.
    expect(find.text('Сны'), findsWidgets);
    expect(find.text('Жизнь'), findsWidgets);
    expect(find.text('Всё'), findsWidgets);
  });

  testWidgets('shows the empty state when there are no entries',
      (tester) async {
    await pumpHome(tester);
    expect(find.text('Записей о снах пока нет'), findsOneWidget);
  });

  testWidgets('shows entry titles from storage', (tester) async {
    final now = DateTime(2026, 1, 2, 10);
    await pumpHome(tester, entries: [
      JournalEntry(
        id: 'e1',
        type: EntryType.dream,
        title: 'Полёт над морем',
        content: 'Летел над волнами',
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    expect(find.text('Полёт над морем'), findsOneWidget);
  });

  testWidgets('tulpa tab only appears when enabled', (tester) async {
    await pumpHome(tester);
    expect(find.text('Тульпы'), findsNothing);

    await pumpHome(tester, tulpaEnabled: true);
    expect(find.text('Тульпы'), findsWidgets);
  });

  testWidgets('switching to the Life tab shows its empty state',
      (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Жизнь').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Записей о жизни пока нет'), findsOneWidget);
  });

  testWidgets('entry cards do not replay their entrance on scroll',
      (tester) async {
    // Regression: the lazy feed disposes off-screen cards, so a card scrolled
    // out and back used to rebuild with a fresh controller and replay its
    // fade+slide — the "записи дёргает и мигает" flicker. The entrance is now
    // a one-shot per entry, so a re-entering card renders fully opaque at once.
    final now = DateTime(2026, 1, 2, 10);
    final entries = [
      for (var i = 0; i < 30; i++)
        JournalEntry(
          id: 'e$i',
          type: EntryType.dream,
          title: 'Запись $i',
          content: 'Текст $i',
          createdAt: now.subtract(Duration(days: i)),
          updatedAt: now.subtract(Duration(days: i)),
        ),
    ];
    await pumpHome(tester, entries: entries);

    final listFinder = find.byType(Scrollable).first;
    // Scroll far down so the first cards are disposed.
    await tester.drag(listFinder, const Offset(0, -4000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Scroll back to the top so those cards are rebuilt.
    await tester.drag(listFinder, const Offset(0, 5000));
    await tester.pump();
    // On the very first frame after re-entering, the leading card must already
    // be at full opacity (no replay). When the card does not animate it is not
    // wrapped in its own FadeTransition, so every FadeTransition above it
    // (app/page transitions) is fully opaque.
    final cardFades = find.ancestor(
      of: find.text('Запись 0'),
      matching: find.byType(FadeTransition),
    );
    for (final element in cardFades.evaluate()) {
      expect((element.widget as FadeTransition).opacity.value, 1.0);
    }
  });
}
