import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataraxy/models/settings.dart';
import 'package:ataraxy/welcome_screen.dart';
import 'package:ataraxy/widgets/press_scale.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => initTestStorage('welcome'));

  Widget build() => testApp(
        WelcomeScreen(
          settings: const AppSettings(),
          onComplete: (_) {},
          onDismiss: () {},
        ),
      );

  testWidgets('shows no tooltips anywhere', (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('notification card offers the enable action', (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(find.text('Включить'), findsOneWidget);
    expect(find.text('Включено'), findsNothing);
  });

  testWidgets('close button has no tooltip', (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    final close = find.byIcon(Icons.close_rounded);
    expect(close, findsOneWidget);
    expect(
      find.ancestor(of: close, matching: find.byType(Tooltip)),
      findsNothing,
    );
  });

  testWidgets('start button completes exactly once per tap', (tester) async {
    var completions = 0;
    await tester.pumpWidget(
      testApp(
        WelcomeScreen(
          settings: const AppSettings(),
          onComplete: (_) => completions++,
          onDismiss: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать пользоваться'));
    await tester.pumpAndSettle();
    expect(completions, 1);
  });

  testWidgets('permission card slides between states', (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    // The enable button carries the same press-dimple as the rest of the app
    // and the card swaps its whole content with an AnimatedSwitcher, so the
    // flip reads as a card change rather than a snap.
    final enable = find.text('Включить');
    expect(
      find.ancestor(of: enable, matching: find.byType(PressScale)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: enable, matching: find.byType(AnimatedSwitcher)),
      findsWidgets,
    );
  });
}
