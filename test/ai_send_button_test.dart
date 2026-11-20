import 'package:flutter_test/flutter_test.dart';
import 'package:ataraxy/compat/material.dart';
import 'package:ataraxy/compat/localizations.dart';
import 'package:ataraxy/screens/ai_assistant_screen.dart';
import 'package:ataraxy/providers/settings_provider.dart';
import 'package:ataraxy/models/settings.dart';
import 'package:ataraxy/theme/app_theme.dart';
import 'package:ataraxy/widgets/press_scale.dart';
import 'helpers.dart';

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
    home: const Scaffold(body: Text('home')),
  ),
);

void _noop() {}

void main() {
  initTestStorage('diag6');
  setUp(resetPrefs);

  testWidgets('send button answers a press with the shared recoil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await settleChat(tester);

    // The send button sits inside the only PressScale in the input bar.
    final scale = find.ancestor(
      of: find.byIcon(Icons.send_rounded),
      matching: find.byType(PressScale),
    );
    expect(scale, findsOneWidget);

    final center = tester.getCenter(find.byIcon(Icons.send_rounded));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 120));
    final pressed = tester.widget<AnimatedScale>(
      find.descendant(of: scale, matching: find.byType(AnimatedScale)).first,
    );
    expect(pressed.scale, lessThan(1.0));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
    final released = tester.widget<AnimatedScale>(
      find.descendant(of: scale, matching: find.byType(AnimatedScale)).first,
    );
    expect(released.scale, 1.0);
  });
}
