import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'ai_overlay_state.dart';
import 'home_content.dart';
import 'models/settings.dart';
import 'providers/settings_provider.dart';
import 'route_observer.dart';
import 'screens/ai_assistant_screen.dart';
import 'services/auto_export_service.dart';
import 'theme/app_theme.dart';
import 'widgets/blood_flow_background.dart';

class AppShell extends StatefulWidget {
  final AppThemeMode themeMode;
  final String? localeCode;
  final GlobalKey<NavigatorState> navigatorKey;
  final ValueNotifier<AppSettings> settingsNotifier;
  final ValueChanged<AppSettings> onSettingsChanged;
  final bool showWelcome;
  final bool authenticated;
  final VoidCallback onUnlocked;
  final VoidCallback onRequestLock;
  final ValueChanged<AppSettings> onWelcomeComplete;
  final VoidCallback onDismissWelcome;

  const AppShell({
    super.key,
    required this.themeMode,
    required this.localeCode,
    required this.navigatorKey,
    required this.settingsNotifier,
    required this.onSettingsChanged,
    required this.showWelcome,
    required this.authenticated,
    required this.onUnlocked,
    required this.onRequestLock,
    required this.onWelcomeComplete,
    required this.onDismissWelcome,
  });

  @override
  State<AppShell> createState() => AppShellState();
}

/// Releases the floating AI chat's keyboard whenever any route covers it
/// (Settings, Statistics, …) — see [aiReleaseKeyboard].
class _KeyboardGuard extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    aiReleaseKeyboard?.call();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    aiReleaseKeyboard?.call();
  }
}

class AppShellState extends State<AppShell> {
  // ThemeData is cached globally inside AppTheme (built once per mode and
  // reused forever) — no per-state cache that gets cleared and rebuilt on
  // every theme switch.
  Timer? _autoExportTimer;
  NavigatorObserver? _keyboardGuard;

  ThemeData _theme(AppThemeMode mode) => AppTheme.of(mode);

  ThemeData _darkTheme(AppThemeMode mode) => AppTheme.darkOf(mode);

  @override
  void initState() {
    super.initState();
    // Any route pushed on top of the app (settings, stats, …) releases the
    // AI chat keyboard, so Flutter's focus restoration can't re-open it on
    // the way back.
    _keyboardGuard = _KeyboardGuard();
    _autoExportTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => AutoExportService().checkAndExport(),
    );
  }

  @override
  void dispose() {
    _autoExportTimer?.cancel();
    _keyboardGuard = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = widget.navigatorKey.currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (!kIsWeb) {
          SystemNavigator.pop();
        }
      },
      child: MaterialApp(
      title: 'Ataraxy',
      debugShowCheckedModeBanner: false,
      navigatorKey: widget.navigatorKey,
      navigatorObservers: [
        appRouteObserver,
        if (_keyboardGuard != null) _keyboardGuard!,
      ],
      themeMode: switch (widget.themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.darkPeach => ThemeMode.dark,
        AppThemeMode.lightLavender => ThemeMode.light,
        AppThemeMode.lightGrok => ThemeMode.light,
        AppThemeMode.lightMaterialYou => ThemeMode.light,
        AppThemeMode.mutilated => ThemeMode.light,
      },
      locale: widget.localeCode != null ? Locale(widget.localeCode!) : null,
      supportedLocales: const [Locale('ru'), Locale('en'), Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: _theme(widget.themeMode),
      darkTheme: _darkTheme(widget.themeMode),
      // Theme + language switches glide: MaterialApp wraps the tree in an
      // AnimatedTheme that lerps every color between the old and new theme
      // over ~380 ms — the canonical flash-free transition (no instant cut,
      // no black/white window peek, no snapshot overlay).
      themeAnimationDuration: const Duration(milliseconds: 380),
      themeAnimationCurve: Curves.easeInOutCubic,
      // Rubber-band "tension" everywhere: swiping past the FIRST tab to the
      // left, past the LAST tab to the right (and pulling any list beyond
      // its top/bottom edge) stretches smoothly and springs back instead of
      // hitting a hard wall. This is the iOS-style bounce the user asked
      // for on the tab edges + vertical overscroll in all sections.
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
      ),
      builder: (context, child) {
        return ListenableBuilder(
          listenable: widget.settingsNotifier,
          builder: (context, _) {
            final settings = widget.settingsNotifier.value;
            return SettingsProvider(
              settings: settings,
              onChanged: widget.onSettingsChanged,
              // MUTILATED theme: a slow blood-flow layer sits behind the
              // (slightly translucent) scaffold and seeps through the
              // section backgrounds.
              child: Stack(
                children: [
                  child!,
                  // Blood layer ON TOP of the whole app (IgnorePointer inside
                  // the widget): visible crimson stains drift over section
                  // backgrounds — the old behind-the-Navigator placement
                  // hid the blood behind translucent surfaces and looked
                  // muddy gray. It also seeps over the splash (MUTILATED's
                  // splash is opaque, so the stains read clearly there).
                  if (widget.themeMode == AppThemeMode.mutilated)
                    const Positioned.fill(
                      child: BloodFlowBackground(),
                    ),
                    // Floating AI assistant on the very TOP: mounted ABOVE
                    // the Navigator so the chat window and bubble hover over
                    // every section (settings, stats, …) and never vanish on
                    // navigation. Regular widget in the tree — not a root
                    // OverlayEntry — so text selection and the keyboard
                    // never hit the grey-screen overlay crash.
                    ValueListenableBuilder<bool>(
                      valueListenable: aiOverlayOpen,
                      builder: (context, open, _) => open
                          ? Positioned.fill(
                              child: AiFloatingAssistant(
                                onClose: () => aiOverlayOpen.value = false,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
          );
      },
      home: HomeContent(
        showWelcome: widget.showWelcome,
        authenticated: widget.authenticated,
        settingsNotifier: widget.settingsNotifier,
        onUnlocked: widget.onUnlocked,
        onRequestLock: widget.onRequestLock,
        onWelcomeComplete: widget.onWelcomeComplete,
        onDismissWelcome: widget.onDismissWelcome,
      ),
    ),
  );
  }
}
