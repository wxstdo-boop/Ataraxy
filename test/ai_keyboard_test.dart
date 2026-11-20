import 'package:flutter_test/flutter_test.dart';
import 'package:ataraxy/compat/material.dart';
import 'package:ataraxy/compat/localizations.dart';
import 'package:ataraxy/screens/ai_assistant_screen.dart';
import 'package:ataraxy/providers/settings_provider.dart';
import 'package:ataraxy/models/settings.dart';
import 'package:ataraxy/theme/app_theme.dart';
import 'helpers.dart';

/// The chat window must not resize or jump when the keyboard opens.
///
/// Android reports the keyboard two ways — `viewInsets.bottom` grows while the
/// surface keeps its height, or the surface itself shrinks (`adjustResize`).
/// Sizing the window from the current height made the input bar lurch on the
/// second variant, and a fixed bottom offset let the keyboard cover the field
/// on the first. Both are covered here.
Widget _app() => SettingsProvider(
  settings: const AppSettings(),
  onChanged: (_) {},
  child: MaterialApp(
    theme: AppTheme.lightMaterialYou(),
    localizationsDelegates: const [
      materialLocalizationsDelegate,
      GlobalWidgetsLocalizations.delegate,
      cupertinoLocalizationsDelegate,
    ],
    supportedLocales: const [Locale('ru'), Locale('en'), Locale('fr')],
    builder: (context, child) => Stack(
      children: [
        child!,
        const Positioned.fill(child: AiFloatingAssistant(onClose: _noop)),
      ],
    ),
    home: const Scaffold(resizeToAvoidBottomInset: false, body: Text('home')),
  ),
);

void _noop() {}

/// The chat window's own box: the decorated Container sized w×h. Identified by
/// its width, which is the compact clamp (280–320) and nothing else in the
/// overlay uses.
Rect _windowBox(WidgetTester tester) {
  final boxes = tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.constraints)
      .whereType<BoxConstraints>()
      .where((c) => c.maxWidth >= 280 && c.maxWidth <= 320 && c.maxHeight > 200)
      .toList();
  expect(boxes, isNotEmpty, reason: 'chat window box not found');
  return Rect.fromLTWH(0, 0, boxes.first.maxWidth, boxes.first.maxHeight);
}

Future<Rect> _pumpWithKeyboard(
  WidgetTester tester, {
  required FakeViewPadding insets,
  bool shrinkSurface = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app());
  await settleChat(tester);
  final windowBefore = _windowBox(tester);

  tester.view.viewInsets = insets;
  if (shrinkSurface) {
    // `adjustResize`: the surface loses exactly the keyboard height.
    tester.view.physicalSize = Size(1080, 2400 - insets.bottom);
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  final after = tester.getRect(find.byType(TextField).first);
  // The box is the geometry that must never change mid-typing.
  expect(
    _windowBox(tester).height,
    closeTo(windowBefore.height, 0.5),
    reason: 'the chat window resized when the keyboard opened',
  );
  return after;
}

void main() {
  initTestStorage('ai_keyboard');
  setUp(resetPrefs);

  testWidgets('viewInsets keyboard lifts the input above itself', (
    tester,
  ) async {
    final after = await _pumpWithKeyboard(
      tester,
      insets: const FakeViewPadding(bottom: 900),
    );
    // 900 physical px / dpr 3 = 300 logical px of keyboard.
    expect(after.bottom, lessThanOrEqualTo(800 - 300));
  });

  testWidgets('adjustResize keyboard does not resize or double-shift', (
    tester,
  ) async {
    final after = await _pumpWithKeyboard(
      tester,
      insets: const FakeViewPadding(bottom: 900),
      shrinkSurface: true,
    );
    expect(after.bottom, lessThanOrEqualTo(500));
  });

  testWidgets('closing the keyboard returns the input to its place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await settleChat(tester);
    final before = tester.getRect(find.byType(TextField).first);

    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.getRect(find.byType(TextField).first), before);
  });
}
