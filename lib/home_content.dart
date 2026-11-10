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
    with TickerProviderStateMixin {
  bool _showSplash = true;
  late AnimationController _splashController;
  late Animation<double> _splashOpacity;
  late AppSettings _lastSettings;

  // Welcome -> home handoff. The home is mounted and PAINTED behind the
  // (opaque) welcome card from the first onboarding frame — exactly the trick
  // the splash uses — so revealing it is a pure opacity fade of the welcome
  // layer over an already-warm screen. The old AnimatedSwitcher built a BRAND
  // NEW HomeScreen at the moment of the switch, so the first frame of the fade
  // had to build + lay out + paint the whole feed in one go: that is the
  // jerky, stuttering transition the user kept reporting.
  late AnimationController _welcomeExit;
  late Animation<double> _welcomeOpacity;
  late bool _welcomeMounted;

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

    _welcomeMounted = widget.showWelcome;
    _welcomeExit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: widget.showWelcome ? 0.0 : 1.0,
    );
    _welcomeOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _welcomeExit, curve: Curves.easeInOutCubic),
    );
    _welcomeExit.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && _welcomeMounted) {
        setState(() => _welcomeMounted = false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant HomeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The child is rebuilt implicitly in build(); just refresh the cached
    // settings snapshot so the structural-change guard below stays accurate.
    _lastSettings = widget.settingsNotifier.value;

    // Onboarding finished (Start button or the close X): fade the welcome
    // layer out over the already-painted home, then unmount it.
    if (oldWidget.showWelcome && !widget.showWelcome && _welcomeMounted) {
      _welcomeExit.forward();
    }
  }

  @override
  void dispose() {
    splashActive.value = false;
    widget.settingsNotifier.removeListener(_onSettingsChanged);
    _splashController.dispose();
    _welcomeExit.dispose();
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

  /// The home screen, pre-built behind the welcome card during onboarding so
  /// it is already laid out and rasterised before the user finishes.
  Widget _home() => HomeScreen(
        key: const ValueKey('home'),
        tulpaEnabled: widget.settingsNotifier.value.tulpaEnabled,
        onRequestLock: widget.onRequestLock,
      );

  @override
  Widget build(BuildContext context) {
    final bg = Container(color: Theme.of(context).scaffoldBackgroundColor);
    final settings = widget.settingsNotifier.value;
    final locked = settings.pin != null && !widget.authenticated;

    // The BASE layer is stable across the whole onboarding hand-off: while the
    // welcome is up it is the (hidden) home, and once the welcome fades away it
    // is the very same home widget — same key, same position in the tree — so
    // nothing remounts at switch time. That is what makes the reveal a plain
    // opacity fade over an already-painted screen instead of a rebuild.
    final Widget base = (locked && !_welcomeMounted)
        ? SettingsProviderPin(
            key: const ValueKey('lock'),
            pin: settings.pin!,
            child: LockScreen(onUnlocked: widget.onUnlocked),
          )
        : _home();

    // The wrapper around [base] must be the SAME widget type in every state.
    // It used to be `Opacity(opacity: 0, child: base)` while onboarding and the
    // bare `base` afterwards — a type change at this slot, so Flutter could not
    // reuse the element and REMOUNTED the whole home subtree the moment the
    // welcome left. Every card re-ran its entrance animation at once: that is
    // the "записи дёргает по двойному" right after the greeting. A stable
    // IgnorePointer (only its `ignoring` flag flips) keeps the home element
    // alive, so the reveal is just the welcome fading off a home that already
    // finished animating behind it.
    final Widget baseLayer = IgnorePointer(
      ignoring: _welcomeMounted,
      child: base,
    );

    // Always keep the same tree shape (base under the splash overlay). If we
    // swapped the Stack for the bare content when the splash finished, the
    // whole subtree would REMOUNT — re-running the welcome intro and the
    // entry-card stagger animations, which looked like a flash + a duplicated
    // "double animation" right after the transition.
    return Stack(
      fit: StackFit.expand,
      children: [
        bg,
        baseLayer,
        // The welcome card, fading out over the already-painted home when
        // onboarding ends. The RepaintBoundary caches its raster so the fade
        // is a pure composited opacity, not a live re-composite every frame.
        if (_welcomeMounted)
          IgnorePointer(
            ignoring: _welcomeExit.value > 0,
            child: FadeTransition(
              opacity: _welcomeOpacity,
              child: RepaintBoundary(
                child: WelcomeScreen(
                  key: const ValueKey('welcome'),
                  settings: settings,
                  onComplete: widget.onWelcomeComplete,
                  onDismiss: widget.onDismissWelcome,
                ),
              ),
            ),
          ),
        IgnorePointer(
          ignoring: !_showSplash,
          // RepaintBoundary sits INSIDE the FadeTransition so the splash
          // subtree (big gradients + artwork) is rasterised ONCE into a
          // texture and the fade is then a pure composited opacity over that
          // cached texture. With the boundary OUTSIDE (the old order) the
          // opacity layer was re-composited from live children every frame,
          // which is what made the exit stutter.
          //
          // NO ScaleTransition here on purpose. Scaling a full-screen texture
          // makes the GPU re-sample every pixel of the whole screen every
          // frame (bilinear filtering over ~1080p), which is exactly the
          // "подтормаживает выход со сплеша" the user kept feeling on
          // mid-range phones. A plain opacity fade is a single cheap blend
          // with zero resampling, so it stays smooth even on weak GPUs.
          child: FadeTransition(
            opacity: _splashOpacity,
            child: RepaintBoundary(
              child: SplashContent(
                opacity: AlwaysStoppedAnimation(1.0),
                contentOpacity: AlwaysStoppedAnimation(1.0),
                // Stop the loading "snake" the moment the fade starts: a
                // spinner repainting every frame underneath the fading layer
                // forces a fresh composite per frame for the whole screen.
                spinning: _showSplash,
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
