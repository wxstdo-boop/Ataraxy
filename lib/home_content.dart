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
  bool _showSplash = true;
  late AnimationController _splashController;
  late Animation<double> _splashOpacity;
  late AppSettings _lastSettings;

  @override
  void initState() {
    super.initState();
    splashActive.value = true;
    _lastSettings = widget.settingsNotifier.value;
    widget.settingsNotifier.addListener(_onSettingsChanged);

    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );

    // The splash is fully opaque from the first frame (so the avatar shows
    // immediately), holds briefly, then melts away with a SINGLE
    // easeInOutCubic fade. That curve starts and ends at zero velocity, so
    // both the hand-off from the hold into the fade AND the end of the fade
    // have no sudden change of speed — the old constant→easeOutQuint sequence
    // jumped straight to full speed as the fade began, which read as a
    // stutter. The content underneath stays fully opaque the whole time — no
    // cross-fade, so no background flash.
    _splashOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.28, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

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
    // The child is rebuilt implicitly in build(); just refresh the cached
    // settings snapshot so the structural-change guard below stays accurate.
    _lastSettings = widget.settingsNotifier.value;
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
    // Only rebuild when something STRUCTURAL changed: the Tulpa tab set or
    // the PIN lock. Everything else (theme, language, water, fasting, …)
    // already propagates through InheritedWidgets, so rebuilding the entire
    // home tree on every toggle was pure waste — it re-ran the whole list
    // build (markdown parse + layout of every entry card).
    final structural =
        settings.tulpaEnabled != _lastSettings.tulpaEnabled ||
        settings.pin != _lastSettings.pin;
    _lastSettings = settings;
    if (structural) setState(() {});
  }

  /// The visible content for the current shell flags. During onboarding the
  /// home screen is kept in the tree BEHIND the welcome card (see build) so
  /// it is already laid out and rasterised before "Начать пользоваться" is
  /// tapped — the cross-fade then just reveals an already-painted screen
  /// instead of building the whole feed in one frame (the lag after the tap).
  Widget _content() {
    final settings = widget.settingsNotifier.value;
    final Widget gated;
    if (widget.showWelcome) {
      gated = WelcomeScreen(
        key: const ValueKey('welcome'),
        settings: settings,
        onComplete: widget.onWelcomeComplete,
        onDismiss: widget.onDismissWelcome,
      );
    } else if (settings.pin != null && !widget.authenticated) {
      gated = SettingsProviderPin(
        key: const ValueKey('lock'),
        pin: settings.pin!,
        child: LockScreen(onUnlocked: widget.onUnlocked),
      );
    } else {
      gated = HomeScreen(
        key: const ValueKey('home'),
        tulpaEnabled: settings.tulpaEnabled,
        onRequestLock: widget.onRequestLock,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        // Pure cross-fade — no slide. Sliding the welcome screen out while
        // the home screen slides in made the two overlap and look like a
        // duplicated "double animation" right after onboarding.
        return FadeTransition(opacity: animation, child: child);
      },
      child: gated,
    );
  }

  /// The home screen pre-built behind the welcome card during onboarding.
  Widget _prebuiltHome() => HomeScreen(
        key: const ValueKey('home'),
        tulpaEnabled: widget.settingsNotifier.value.tulpaEnabled,
        onRequestLock: widget.onRequestLock,
      );

  @override
  Widget build(BuildContext context) {
    final bg = Container(color: Theme.of(context).scaffoldBackgroundColor);

    // Onboarding: keep the welcome card on top of the home screen, which is
    // mounted but hidden so it warms up (data loaded, first layout + paint
    // done) before the user finishes. Offstage+Opacity(0) keeps it laid out
    // and painted while invisible, so "Начать пользоваться" reveals an
    // already-ready screen. IgnorePointer + the covering welcome card keep
    // the hidden home from receiving input.
    final Widget content = widget.showWelcome
        ? Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: 0,
                child: IgnorePointer(child: _prebuiltHome()),
              ),
              _content(),
            ],
          )
        : _content();

    // Always keep the same tree shape (content under the splash overlay). If
    // we swapped the Stack for the bare content when the splash finished, the
    // whole subtree would REMOUNT — re-running the welcome intro and the
    // entry-card stagger animations, which looked like a flash + a duplicated
    // "double animation" right after the transition.
    return Stack(
      fit: StackFit.expand,
      children: [
        bg,
        content,
        IgnorePointer(
          ignoring: !_showSplash,
          // RepaintBoundary: the splash subtree (big gradients + artwork) is
          // rasterised ONCE into a texture and the fade is then a pure
          // composited opacity — no re-rasterisation per frame.
          //
          // NO ScaleTransition here on purpose. Scaling a full-screen texture
          // makes the GPU re-sample every pixel of the whole screen every
          // frame (bilinear filtering over ~1080p), which is exactly the
          // "подтормаживает выход со сплеша" the user kept feeling on
          // mid-range phones. A plain opacity fade is a single cheap blend
          // with zero resampling, so it stays smooth even on weak GPUs.
          child: RepaintBoundary(
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
        ),
      ],
    );
  }
}
