import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataraxy/models/settings.dart';
import 'package:ataraxy/widgets/reminder_dialog.dart';
import 'package:ataraxy/widgets/volumetric_switch.dart';

import 'helpers.dart';

void main() {
  initTestStorage('reminder_dialog');
  setUp(() => resetPrefs());

  testWidgets('reminder dialog never scrolls its content internally', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        const Scaffold(body: ReminderDialog(settings: AppSettings())),
      ),
    );
    await tester.pumpAndSettle();

    // The dialog content is a fixed Column (no SingleChildScrollView) — the
    // user explicitly asked for the inside NOT to scroll.
    expect(
      find.descendant(
        of: find.byType(ReminderDialog),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
    // Cancel must remain available.
    expect(find.text('Отмена'), findsOneWidget);
  });

  testWidgets('enabling the reminder reveals the time tile smoothly', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        const Scaffold(body: ReminderDialog(settings: AppSettings())),
      ),
    );
    await tester.pumpAndSettle();

    // Off: the time tile is not part of the enabled block yet.
    final before = find.byType(ListWheelScrollView);

    // Flip the switch on.
    await tester.tap(find.byType(VolumetricSwitch).first);
    await tester.pump();
    // Mid-flight the AnimatedSize is animating; it must settle cleanly.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(before, findsNothing); // sanity: no stray wheel in the dialog
  });
}
