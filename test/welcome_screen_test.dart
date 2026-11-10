import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataraxy/models/settings.dart';
import 'package:ataraxy/welcome_screen.dart';

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
}
