import 'package:flutter/material.dart';
import 'models/settings.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'splash_content.dart';
import 'splash_state.dart';
import 'theme/app_theme.dart';
import 'welcome_screen.dart';

class HomeContent extends StatefulWidget {
  final bool showWelcome;
  final bool authenticated;
  final ValueNotifier<AppSettings> settingsNotifier;
  final VoidCallback onUnlocked;
  final VoidCallback onRequestLock;
  final ValueChanged<AppSettings> onWelcomeComplete;
  final VoidCallback onDismissWelcome;

  const HomeContent({
    super.key,
    required this.showWelcome,
    required this.authenticated,
    required this.settingsNotifier,
    required this.onUnlocked,
    required this.onRequestLock,
    required this.onWelcomeComplete,
    required this.onDismissWelcome,
  });

  @override
  State<HomeContent> createState() => HomeContentState();
}

class HomeContentState extends State<HomeContent>
    with SingleTickerProviderStateMixin {
  Widget _child = const SizedBox.shrink();
  bool _showSplash = true;
  late AnimationController _splashController;
  late Animation<double> _splashOpacity;
  late AppSettings _lastSettings;

  @override
  void initState() {
    super.initState();
    splashActive.value = true;
    _lastSettings = widget.settingsNotifier.value;
    _child = _buildChild(_lastSettings);
    widget.settingsNotifier.addListener(_onSettingsChanged);

    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // The splash is fully opaque from the first frame (so the avatar shows
    // immediately), holds, then fades away smoothly. The content underneath
    // is fully opaque the whole time — no cross-fade, so no background
    // "flash" and no abrupt swap at the end.
    _splashOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 45,
      ),
    ]).animate(_splashController);

    _splashController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        splashActive.value = false;
        setState(() {
          _showSplash = false;
        });
      }
    });
    _splashController.forward();
  }

  @override
  void didUpdateWidget(covariant HomeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild the child whenever the shell tells us the active screen
    // changed. Without this the welcome/lock screens get stuck: the child is
    // only refreshed on settings-notifier events, so the dismiss (×) button
    // never worked and "Начать пользоваться" needed a second tap.
    if (oldWidget.showWelcome != widget.showWelcome ||
        oldWidget.authenticated != widget.authenticated) {
      _child = _buildChild(widget.settingsNotifier.value);
    }
  }

  @override
  void dispose() {
    splashActive.value = false;
    widget.settingsNotifier.removeListener(_onSettingsChanged);
    _splashController.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    final settings = widget.settingsNotifier.value;
    // Only rebuild the child when something STRUCTURAL changed: the Tulpa
    // tab set or the PIN lock. Everything else (theme, language, water,
    // fasting, …) already propagates through InheritedWidgets, so rebuilding
    // the entire home tree on every toggle was pure waste — it re-ran the
    // whole list build (markdown parse + layout of every entry card).
    if (settings.tulpaEnabled == _lastSettings.tulpaEnabled &&
        settings.pin == _lastSettings.pin) {
      return;
    }
    _lastSettings = settings;
    setState(() => _child = _buildChild(settings));
  }

  Widget _buildChild(AppSettings settings) {
    if (widget.showWelcome) {
      return WelcomeScreen(
        key: const ValueKey('welcome'),
        settings: settings,
        onComplete: widget.onWelcomeComplete,
        onDismiss: widget.onDismissWelcome,
      );
    }
    if (settings.pin != null && !widget.authenticated) {
      return SettingsProviderPin(
        key: const ValueKey('lock'),
        pin: settings.pin!,
        child: LockScreen(onUnlocked: widget.onUnlocked),
      );
    }
    return HomeScreen(
      key: const ValueKey('home'),
      tulpaEnabled: settings.tulpaEnabled,
      onRequestLock: widget.onRequestLock,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          // Pure cross-fade — no slide. Sliding the welcome screen out while
          // the home screen slides in made the two overlap and look like a
          // duplicated "double animation" right after onboarding.
          return FadeTransition(opacity: animation, child: child);
        },
        child: _child,
      ),
    );

    // Always keep the same tree shape (content under the splash overlay). If
    // we swapped the Stack for the bare content when the splash finished, the
    // whole subtree would REMOUNT — re-running the welcome intro and the
    // entry-card stagger animations, which looked like a flash + a duplicated
    // "double animation" right after the transition.
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        IgnorePointer(
          ignoring: !_showSplash,
          child: FadeTransition(
            opacity: _splashOpacity,
            child: SplashContent(
              opacity: AlwaysStoppedAnimation(1.0),
              contentOpacity: AlwaysStoppedAnimation(1.0),
              // MUTILATED: the splash background is fully opaque; other
              // themes keep the soft translucent theme gradient.
              opaque: _lastSettings.themeMode == AppThemeMode.mutilated,
            ),
          ),
        ),
      ],
    );
  }
}
