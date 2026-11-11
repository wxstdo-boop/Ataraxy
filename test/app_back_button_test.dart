import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ataraxy/widgets/app_back_button.dart';
import 'package:ataraxy/widgets/pressable_icon_button.dart';

void main() {
  testWidgets('AppBackButton renders a press-recoil icon button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(leading: const AppBackButton()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byType(PressableIconButton), findsOneWidget);
  });

  testWidgets('AppBackButton never shows a tooltip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(leading: const AppBackButton()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Tooltip), findsNothing);

    // A long-press used to surface the localized "Назад" tooltip; make sure
    // none appears even after holding the button.
    await tester.longPress(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('AppBackButton invokes the custom handler', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(leading: AppBackButton(onPressed: () => taps++)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
