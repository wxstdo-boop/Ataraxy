import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ataraxy/l10n/strings.dart';
import 'package:ataraxy/providers/settings_provider.dart';
import 'package:ataraxy/services/ai_service.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:ataraxy/widgets/limited_context_menu.dart';
import 'package:ataraxy/ai_overlay_state.dart';
import 'package:ataraxy/widgets/em_dash_formatter.dart';
import 'package:ataraxy/widgets/pressable_icon_button.dart';
import 'package:ataraxy/providers/chat_controller.dart';
import 'package:ataraxy/theme/app_theme.dart';

/// АДА — floating AI assistant. A big draggable bubble that hovers over the
/// app; tap it to expand into a chat window. The chat has read access to all
/// journal entries and can create / edit them through JSON commands the
/// model emits in a fenced ```json block.
///
/// NOTE: this is deliberately a PLAIN widget mounted inside the app's own
/// widget tree (home screen Stack), NOT an OverlayEntry in the root overlay.
/// The root-overlay version caused a whole class of grey-screen crashes:
/// overlay entries above the Navigator have no Material ancestor (TextField
/// threw "No Material widget found"), a top-level Positioned hit a null
/// parentData, and the text-selection toolbar entries (long-press on a
/// message / input field) raced with the root overlay's lifecycle — every
/// one of those became a full-screen grey ErrorWidget in release builds.
class AiFloatingAssistant extends StatefulWidget {
  final VoidCallback onClose;
  const AiFloatingAssistant({super.key, required this.onClose});

  @override
  State<AiFloatingAssistant> createState() => AiFloatingAssistantState();
}

/// Public state so the host (home screen) can trigger the animated close
/// (fade+scale) on a repeated long-press instead of hard-unmounting.
class AiFloatingAssistantState extends State<AiFloatingAssistant>
    with TickerProviderStateMixin {
  late final AnimationController _appear;
  late final AnimationController _bubblePulse;
  // Plays a fade+scale-out before the overlay is actually removed, so
  // closing is animated instead of a hard snap.
  late final AnimationController _closing;
  // Glides the drag offset to a target (edge snap / re-clamp on open) so
  // the bubble and window fly smoothly instead of jumping.
  late final AnimationController _snap;
  Animation<Offset>? _snapAnim;
  bool _minimized = false;

  // Drag position — a ValueNotifier so dragging repaints only the
  // Transform layer instead of rebuilding the whole window subtree.
  final ValueNotifier<Offset> _drag = ValueNotifier(Offset.zero);
  final ValueNotifier<bool> _dragging = ValueNotifier(false);

  final _chat = ChatController();
  bool _chatReady = false;

  // --- Auto-float: the bubble drifts by itself across the screen ---
  // A lightweight timer nudges the drag offset along a CONTINUOUS steering
  // direction (sine/cosine of the wall-clock) at a CONSTANT speed. The
  // direction changes smoothly every instant, so the bubble wanders in a
  // calm curve and NEVER stalls (the old random-walk velocity decayed to
  // ~0 at the walls and the bubble froze there). Stops while the user is
  // dragging or when the chat window is open.
  Timer? _driftTimer;

  bool _chatInitStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_chatInitStarted) return;
    _chatInitStarted = true;
    // The chat's daily budget must come from SETTINGS (not the hardcoded
    // 1300 default) — otherwise the empty state shows a wrong "осталось N"
    // that ignores the limit the user configured.
    final limit = SettingsProvider.of(context).settings.aiDailyLimit;
    _chat.init(limit: limit).then((_) {
      if (mounted) setState(() => _chatReady = true);
      // A long restored history must open on the LAST message instantly.
      _chat.jumpToBottom();
    });
  }

  @override
  void initState() {
    super.initState();
    // Register the keyboard-release hook so AppShell can unfocus the chat
    // input when any route covers the app.
    aiReleaseKeyboard = _chat.unfocusInput;
    _appear = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();
    // Gentle autonomous motion: 33ms tick at a steady ~0.9 px/tick
    // (≈27 px/s cruise). The heading is a continuous function of time, so
    // the path curves smoothly and the speed never drops to zero — AND a
    // wall-repulsion force turns the bubble inward BEFORE it reaches the
    // border, so it never parks on or jitters against an edge.
    _driftTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted || !_minimized || _dragging.value || _closing.isAnimating) {
        return;
      }
      final size = MediaQuery.of(context).size;
      final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
      // Continuously turning heading: two slow sine waves at different
      // rates → an organic lissajous-ish wander with no repeats.
      final angle =
          math.sin(now * 0.21) * 1.1 + math.cos(now * 0.13) * 0.7;
      const cruise = 0.9; // px per tick — constant, never stalls
      var vx = math.cos(angle) * cruise;
      var vy = math.sin(angle) * 0.55 * cruise;
      // Wall repulsion: the closer to an edge, the stronger the heading is
      // pushed inward. The bubble turns around at a comfortable margin and
      // keeps gliding — it never touches the border, let alone sticks to it.
      const b = 50.0;
      final minX = 16 + b / 2 - size.width;
      final maxX = 16 + b / 2;
      final minY = 90 + b / 2 - size.height;
      final maxY = 90 + b / 2;
      const margin = 90.0;
      const rep = 2.6; // max push, px/tick
      final pos = _drag.value;
      if (pos.dx - minX < margin) {
        vx += (1 - (pos.dx - minX) / margin) * rep;
      }
      if (maxX - pos.dx < margin) {
        vx -= (1 - (maxX - pos.dx) / margin) * rep;
      }
      if (pos.dy - minY < margin) {
        vy += (1 - (pos.dy - minY) / margin) * rep * 0.55;
      }
      if (maxY - pos.dy < margin) {
        vy -= (1 - (maxY - pos.dy) / margin) * rep * 0.55;
      }
      // Keep total speed sane even when a corner pushes on both axes.
      final len = math.sqrt(vx * vx + vy * vy);
      if (len > 2.4) {
        vx = vx / len * 2.4;
        vy = vy / len * 2.4;
      }
      var next = pos + Offset(vx, vy);
      final clamped = _clampDrag(next, size, true);
      if (clamped != next) {
        // Safety net (rarely triggers now): reflect the offending axis.
        next = Offset(
          clamped.dx != next.dx ? pos.dx - vx : next.dx,
          clamped.dy != next.dy ? pos.dy - vy : next.dy,
        );
      }
      _drag.value = _clampDrag(next, size, true);
    });
    _bubblePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    // Stop the pulse when the chat window is open: the bubble is not visible
    // then, but the repeating controller would otherwise keep ticking and
    // rebuild its AnimatedBuilder subtree every frame — a real battery/CPU
    // drain on mid-range phones. Restart it when minimized again.
    _bubblePulse.addStatusListener((status) {
      if (!mounted) return;
      if (_minimized && status == AnimationStatus.completed) {
        _bubblePulse.repeat(reverse: true);
      }
    });
    _closing = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _snap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  /// Smoothly flies the drag offset to [target] (used for edge-snap and for
  /// pulling the chat window back fully on-screen when it was opened from a
  /// bubble parked at an edge).
  void _animateDragTo(Offset target) {
    _snap.stop();
    final from = _drag.value;
    if ((from - target).distance < 0.5) return;
    _snapAnim = Tween<Offset>(begin: from, end: target).animate(
      CurvedAnimation(parent: _snap, curve: Curves.easeOutCubic),
    );
    void listener() {
      final anim = _snapAnim;
      if (anim != null) _drag.value = anim.value;
    }

    _snap.addListener(listener);
    _snap.forward(from: 0);
  }

  @override
  void dispose() {
    if (aiReleaseKeyboard == _chat.unfocusInput) {
      aiReleaseKeyboard = null;
    }
    _driftTimer?.cancel();
    _appear.dispose();
    _bubblePulse.dispose();
    _closing.dispose();
    _snap.dispose();
    _drag.dispose();
    _dragging.dispose();
    _chat.dispose();
    super.dispose();
  }

  /// Animates the close (fade + scale down), then asks the parent to
  /// unmount this assistant. The keyboard is released before the fade so
  /// it never lingers over the home screen.
  void close() {
    if (!mounted || _closing.isAnimating) return;
    _chat.unfocusInput();
    _closing.forward().whenComplete(() {
      if (mounted) widget.onClose();
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final size = MediaQuery.of(context).size;
    final next = _drag.value + Offset(d.delta.dx, d.delta.dy);
    _drag.value = _clampDrag(next, size, _minimized);
  }

  /// Clamps a drag offset so the moving surface stays reachable:
  ///  • bubble — may peek out by up to half of its size (grabable at edges);
  ///  • chat window — must stay FULLY on screen (anchored right/bottom).
  Offset _clampDrag(Offset next, Size size, bool bubble) {
    if (bubble) {
      const b = 50.0; // bubble size
      return Offset(
        next.dx.clamp(16 + b / 2 - size.width, 16 + b / 2),
        next.dy.clamp(90 + b / 2 - size.height, 90 + b / 2),
      );
    }
    final w = size.width.clamp(280.0, 320.0);
    final h = (size.height * 0.44).clamp(280.0, 480.0);
    // Keep the window fully inside the screen: never under the status bar
    // (top safe area + small margin) and never past the bottom edge. The
    // assistant now covers the whole Scaffold, so the clamp must use the
    // real screen size plus the top padding.
    final topSafe = MediaQuery.paddingOf(context).top + 8;
    return Offset(
      next.dx.clamp(w + 8 - size.width, 8),
      // min: window top never goes above the status bar (topSafe);
      // max: window bottom never below its rest position (screen bottom).
      next.dy.clamp(h + 10 + topSafe - size.height, 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    // Compact window. Slightly wider so the assistant description fits
    // comfortably in the empty state.
    final w = size.width.clamp(280.0, 320.0);
    final h = (size.height * 0.44).clamp(280.0, 480.0);

    // Transparent Material + SizedBox.expand: the assistant is mounted
    // inside the home screen's Stack, and a Material ancestor guarantees
    // TextField/IconButton always have their required sheet even if the
    // host ever moves the widget outside a Scaffold.
    return Material(
      type: MaterialType.transparency,
      child: SizedBox.expand(
        child: RepaintBoundary(
          child: FadeTransition(
        // Close animation: fade + scale down, then the host is dismissed.
        opacity: Tween(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(parent: _closing, curve: Curves.easeInCubic),
        ),
        child: ScaleTransition(
          scale: Tween(begin: 1.0, end: 0.8).animate(
            CurvedAnimation(parent: _closing, curve: Curves.easeInCubic),
          ),
          child: FadeTransition(
            opacity: _appear,
            child: ScaleTransition(
              scale: Tween(begin: 0.85, end: 1.0).animate(
                CurvedAnimation(parent: _appear, curve: Curves.easeOutBack),
              ),
              // Smoothly morph between the window and the bubble when
              // minimizing / expanding. Distinct ValueKeys are REQUIRED —
              // both branches are Stack-shaped widgets, and without keys the
              // AnimatedSwitcher treats them as the same child and skips the
              // transition entirely (a hard snap).
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.7, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: _minimized
                    ? KeyedSubtree(
                        key: const ValueKey('bubble'),
                        child: _bubble(scheme),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('window'),
                        child: _window(scheme, w, h),
                      ),
              ),
            ),
          ),
        ),
      ),
      ),
      ),
    );
  }

  // ============ Big bubble ============

  Widget _bubble(ColorScheme scheme) {
    // The Positioned must live inside a Stack — without one the
    // parent-data is ignored and the bubble stretches to the whole screen
    // (a full-screen gray blob). The Stack itself stays transparent, so
    // taps outside the bubble pass through to the app underneath.
    return Stack(
      children: [
        ValueListenableBuilder<Offset>(
          valueListenable: _drag,
          builder: (context, pos, child) => Positioned(
            right: 16,
            bottom: 90,
            child: Transform.translate(offset: pos, child: child),
          ),
          child: RepaintBoundary(
            child: GestureDetector(
              onTap: () {
                setState(() => _minimized = false);
                _bubblePulse.stop();
                // Reopening the window recreates the ListView at the top —
                // land straight on the newest message.
                _chat.jumpToBottom();
                // Pull the window back fully on-screen: a bubble parked at
                // the left edge used to open the chat half off-screen.
                final clamped = _clampDrag(
                  _drag.value,
                  MediaQuery.of(context).size,
                  false,
                );
                if (clamped != _drag.value) _animateDragTo(clamped);
              },
              onPanStart: (_) {
                _snap.stop();
                _dragging.value = true;
              },
              onPanUpdate: _onPanUpdate,
              onPanEnd: (_) => _dragging.value = false,
              child: ValueListenableBuilder<bool>(
                valueListenable: _dragging,
                builder: (context, dragging, child) => AnimatedScale(
                  scale: dragging ? 0.9 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: child,
                ),
                child: _bubbleBody(scheme),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubbleBody(ColorScheme scheme) {
    return AnimatedBuilder(
      animation: _bubblePulse,
      builder: (context, child) {
        final p = _bubblePulse.value; // 0..1
        // Compact (44px), theme-aware bubble with a soft light pulse and a
        // crisp outline so it reads sharply over any background.
        return Container(
          width: 44 + p * 2.5,
          height: 44 + p * 2.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary, scheme.tertiary],
            ),
            // Crisp 1.6px light rim + dark outer contour for definition.
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.45 + p * 0.2),
                blurRadius: 14 + p * 6,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
              // Subtle edge darkening behind the rim = depth.
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 1,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Inner ring — stronger white for contrast.
              Container(
                width: 33,
                height: 33,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                ),
              ),
              Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 18,
                shadows: const [
                  Shadow(color: Colors.black38, blurRadius: 3),
                ],
              ),
              // Sparkle
              Positioned(
                top: 5,
                right: 5,
                child: Icon(
                  Icons.star_rounded,
                  size: 8,
                  color: Colors.white,
                  shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============ Chat window ============

  Widget _window(ColorScheme scheme, double w, double h) {
    // Same as the bubble: Positioned must be inside a Stack, otherwise the
    // window is stretched to the full screen instead of staying compact.
    // The window is anchored at a FIXED bottom offset — it never jumps when
    // the keyboard opens (user preference), so no viewInsets math here.
    return Stack(
      children: [
        ValueListenableBuilder<Offset>(
          valueListenable: _drag,
          builder: (context, pos, child) => Positioned(
            right: 8,
            bottom: 10,
            child: Transform.translate(offset: pos, child: child),
          ),
          child: RepaintBoundary(
            child: ValueListenableBuilder<bool>(
              valueListenable: _dragging,
              builder: (context, dragging, child) => AnimatedScale(
                scale: dragging ? 0.97 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: child,
              ),
              child: ListenableBuilder(
                listenable: _chat,
                builder: (context, _) => Container(
                  width: w,
                  height: h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    // FULLY OPAQUE background — the previous translucent
                    // gradient let the app behind (and the keyboard)
                    // bleed through and read as a muddy gray screen while
                    // typing. Solid surface keeps the chat crisp on every
                    // theme.
                    color: scheme.surfaceContainerLow,
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.28),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 34,
                        offset: const Offset(0, 14),
                      ),
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.2),
                        blurRadius: 40,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _dragHandle(scheme),
                      _header(scheme),
                      const Divider(height: 1),
                      Expanded(
                        child: !_chatReady
                            ? const Center(child: CircularProgressIndicator())
                            : _AiChatBody(controller: _chat),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dragHandle(ColorScheme scheme) {
    return GestureDetector(
      onPanStart: (_) => _dragging.value = true,
      onPanUpdate: _onPanUpdate,
      onPanEnd: (_) => _dragging.value = false,
      child: Container(
        height: 30,
        color: Colors.transparent,
        child: Center(
          child: ValueListenableBuilder<bool>(
            valueListenable: _dragging,
            builder: (context, dragging, child) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                // Theme-aware handle (was hardcoded purple).
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.tertiary],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: dragging
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(ColorScheme scheme) {
    // Two rows: identity (avatar + name + status) on top, then the
    // Free/ADA toggle ABOVE the window controls (clear/minimize/close).
    // This gives the name full width ("АДА" never wraps) and keeps the
    // provider switch clearly separated from the control buttons.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 6, 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // ADA avatar — gradient ring + inner circle, theme-aware.
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primary, scheme.tertiary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surface,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: scheme.primary,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'АДА',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.3,
                        color: scheme.onSurface,
                      ),
                    ),
                    // Status dot + label. A fixed-height stack cross-fades
                    // «онлайн» ↔ «Думаю…» with a tiny upward slide, so the
                    // wider text never makes the header jump horizontally.
                    SizedBox(
                      height: 13,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.35),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            ...previousChildren,
                            ?currentChild,
                          ],
                        ),
                        child: Row(
                          key: ValueKey(_chat.busy),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 320),
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _chat.busy
                                    ? AppAccents.amber
                                    : AppAccents.sage,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_chat.busy
                                            ? AppAccents.amber
                                            : AppAccents.sage)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _chat.busy
                                  ? L.tr(context, 'aiThinking')
                                  : L.tr(context, 'aiOnline'),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Streak + points mini-badges — always visible so the user
              // can see their reward progress at a glance.
              _RewardBadges(
                streak: _chat.streak,
                points: _chat.points,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _ProviderToggle(
                provider: _chat.provider,
                onChanged: (p) => _chat.provider = p,
              ),
              const Spacer(),
              PressableIconButton(
                size: 36,
                tooltip: L.tr(context, 'aiClearChat'),
                icon: Icon(
                  Icons.delete_sweep_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: _chat.messages.isEmpty ? null : _chat.clear,
              ),
              PressableIconButton(
                size: 36,
                tooltip: L.tr(context, 'minimize'),
                icon: Icon(
                  Icons.remove_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: () {
                  _chat.unfocusInput(); // keyboard closes with the window
                  setState(() => _minimized = true);
                  _bubblePulse.repeat(reverse: true);
                  final clamped = _clampDrag(
                    _drag.value,
                    MediaQuery.of(context).size,
                    true,
                  );
                  if (clamped != _drag.value) _animateDragTo(clamped);
                },
              ),
              PressableIconButton(
                size: 36,
                tooltip: L.tr(context, 'close'),
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: close,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Two compact pill badges (🔥 streak / ✨ points) shown in the chat header.
class _RewardBadges extends StatelessWidget {
  final int streak;
  final int points;
  const _RewardBadges({required this.streak, required this.points});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget pill(IconData icon, Color tint, String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tint.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: tint),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pill(Icons.local_fire_department_rounded, AppAccents.amber,
            '$streak'),
        const SizedBox(width: 4),
        pill(Icons.star_rounded, scheme.primary, '$points'),
      ],
    );
  }
}

/// The chat body: message list + input bar. Rebuilds when the controller
/// notifies (new message, busy toggling).
class _AiChatBody extends StatelessWidget {
  final ChatController controller;
  const _AiChatBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return Column(
          children: [
            Expanded(
              // Fade the whole list out while clearing, then the empty
              // state fades back in — a smooth clear instead of a hard snap.
              child: AnimatedOpacity(
                opacity: c.clearing ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                child: c.messages.isEmpty
                    ? _EmptyState(
                        entriesCount: c.entriesCount,
                        remaining: c.remainingToday,
                      )
                    : RepaintBoundary(
                        // Keep the (heavy SelectableText) message list on its
                        // own raster layer so busy/typing rebuilds of the
                        // input bar & header don't re-layout every bubble.
                        child: ListView.builder(
                          controller: c.scroll,
                          padding: const EdgeInsets.all(10),
                          itemCount: c.messages.length,
                          itemBuilder: (context, i) {
                            final m = c.messages[i];
                            return _AnimatedMessage(
                              message: m,
                              scheme: scheme,
                              // Only the last assistant bubble is "live"
                              // while the model types into it.
                              streaming: c.streaming &&
                                  i == c.messages.length - 1 &&
                                  m.role == 'assistant',
                            );
                          },
                        ),
                      ),
              ),
            ),
            // Rewards no longer render as a banner here: after the reply
            // lands they're flushed INTO the message list (role 'reward')
            // with the same animation as every other message.
            _InputBar(
              controller: c.input,
              focusNode: c.inputFocus,
              onSend: () {
                c.send(context);
                c.scrollToBottom();
              },
              enabled: !c.busy,
            ),
          ],
        );
      },
    );
  }
}

/// Segmented Free/ADA/Laguna switch: a gradient pill that smoothly slides
/// from the active slot to the tapped one. A LayoutBuilder computes the
/// exact slot width and an AnimatedPositioned moves the pill deterministically
/// — no ambiguity, the whole tab visibly slides.
class _ProviderToggle extends StatelessWidget {
  final String provider; // 'free' | 'ada' | 'laguna'
  final ValueChanged<String> onChanged;
  const _ProviderToggle({required this.provider, required this.onChanged});

  static const double _h = 26;

  /// Third slot label follows the pasted key: a Groq/NVIDIA/Gemini key
  /// replaces "Laguna" in the tab (the key decides the backend).
  List<String> _labels(BuildContext context) {
    final key = SettingsProvider.of(context).settings.aiKey;
    if (key != null && key.isNotEmpty) {
      return ['Free', 'ADA', AiService.providerForKey(key).label];
    }
    return const ['Free', 'ADA', 'Laguna'];
  }

  int get _index {
    switch (provider) {
      case 'ada':
        return 1;
      case 'laguna':
        return 2;
      default:
        return 0;
    }
  }

  /// The value stored for a slot index is FIXED ('free'/'ada'/'laguna') —
  /// only the visible label changes with the pasted key.
  String _valueFor(int i) {
    switch (i) {
      case 1:
        return 'ada';
      case 2:
        return 'laguna';
      default:
        return 'free';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labels = _labels(context);
    // Fixed width is REQUIRED: inside a Row the LayoutBuilder would receive
    // unbounded maxWidth → slot = infinity → the whole header collapses and
    // every control disappears. Wider when a long provider label (e.g.
    // OpenRouter) is active so the tab text never wraps.
    final width = labels.any((l) => l.length > 7) ? 208.0 : 168.0;
    return SizedBox(
      width: width,
      height: _h + 6,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(3),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final total = constraints.maxWidth;
            final slot = total / labels.length;
            return SizedBox(
              height: _h,
              child: Stack(
                children: [
                  // The sliding pill: exactly the active slot.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    left: _index * slot,
                    top: 0,
                    bottom: 0,
                    width: slot,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [scheme.primary, scheme.tertiary],
                        ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.45),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        _ToggleOpt(
                          label: labels[i],
                          width: slot,
                          height: _h,
                          selected: _index == i,
                          onTap: () => onChanged(_valueFor(i)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ToggleOpt extends StatelessWidget {
  final String label;
  final double width;
  final double height;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleOpt({
    required this.label,
    required this.width,
    required this.height,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : scheme.onSurfaceVariant,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final int entriesCount;
  final int remaining;
  const _EmptyState({required this.entriesCount, required this.remaining});

  /// «Вижу N записей в твоём дневнике» with proper Russian plural forms
  /// (1 запись / 2-4 записи / 5+ записей) — the generic "записей" read
  /// wrong for small counts and the old build's "запись(и-ей)" was ugly.
  String _analyzesLabel(BuildContext context) {
    final n = entriesCount;
    final localized = L.tr(context, 'aiAnalyzes').replaceAll(
      '{n}',
      n.toString(),
    );
    if (Localizations.localeOf(context).languageCode != 'ru') {
      return localized;
    }
    final n10 = n % 10;
    final n100 = n % 100;
    final String word;
    if (n10 == 1 && n100 != 11) {
      word = 'запись';
    } else if (n10 >= 2 && n10 <= 4 && (n100 < 12 || n100 > 14)) {
      word = 'записи';
    } else {
      word = 'записей';
    }
    return 'Вижу $n $word в твоём дневнике';
  }

  /// «Сегодня осталось N сообщений» with proper Russian plural forms
  /// (1 сообщение / 2-4 сообщения / 5+ сообщений) — the flat "сообщений"
  /// read wrong for small remaining counts.
  String _remainingLabel(BuildContext context) {
    final n = remaining;
    final localized = L.tr(context, 'aiRemaining').replaceAll(
      '{n}',
      n.toString(),
    );
    if (Localizations.localeOf(context).languageCode != 'ru') {
      return localized;
    }
    final n10 = n % 10;
    final n100 = n % 100;
    final String word;
    if (n10 == 1 && n100 != 11) {
      word = 'сообщение';
    } else if (n10 >= 2 && n10 <= 4 && (n100 < 12 || n100 > 14)) {
      word = 'сообщения';
    } else {
      word = 'сообщений';
    }
    return 'Сегодня осталось $n $word';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      // Compact + slightly raised so the description never overlaps the
      // input bar on small windows.
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.tertiary],
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: scheme.onPrimary,
              size: 21,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            L.tr(context, 'aiEmptyTitle'),
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            L.tr(context, 'aiEmptyHint'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11.5,
                  height: 1.3,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _analyzesLabel(context),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            _remainingLabel(context),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Message bubble that eases in with a fade + slide from its side, so new
/// messages visibly appear instead of snapping into the list.
class _AnimatedMessage extends StatefulWidget {
  final AiMessageUi message;
  final ColorScheme scheme;
  /// True while this bubble is the live stream target (model typing).
  final bool streaming;
  const _AnimatedMessage({
    required this.message,
    required this.scheme,
    this.streaming = false,
  });

  @override
  State<_AnimatedMessage> createState() => _AnimatedMessageState();
}

class _AnimatedMessageState extends State<_AnimatedMessage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    final curved = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
    );
    _opacity = curved;
    final role = widget.message.role;
    // Reward celebration glides up from below the input; user/assistant
    // bubbles slide in from their own side.
    final begin = role == 'reward'
        ? const Offset(0, 0.7)
        : Offset(role == 'user' ? 0.35 : -0.35, 0);
    _slide = Tween<Offset>(begin: begin, end: Offset.zero).animate(curved);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: _Bubble(
          message: widget.message,
          scheme: widget.scheme,
          streaming: widget.streaming,
        ),
      ),
    );
  }
}

class _Bubble extends StatefulWidget {
  final AiMessageUi message;
  final ColorScheme scheme;
  final bool streaming;
  const _Bubble({
    required this.message,
    required this.scheme,
    this.streaming = false,
  });

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  // Memoized markdown subtree: while the model streams a reply, EVERY
  // notify rebuilds the whole message list — and MarkdownBody re-parses
  // its source on every build. Older messages never change, so we cache
  // their parsed subtree and reuse it until content/role actually changes.
  Widget? _cachedChild;
  String? _cacheKey;

  @override
  void didUpdateWidget(_Bubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    final key = _cacheKeyFor(widget.message, widget.scheme);
    if (key != _cacheKey) {
      _cachedChild = null;
    }
  }

  static String _cacheKeyFor(AiMessageUi m, ColorScheme s) {
    // Content+role+reasoning for message identity; the scheme's primary is
    // a cheap stand-in for "the theme changed" so a cached parse is never
    // reused across a theme switch with wrong colours.
    return '${m.role}|${m.content}|${m.reasoning}|${s.primary.toARGB32()}';
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final scheme = widget.scheme;
    if (widget.streaming) {
      // Stream fast-path: MarkdownBody re-parses its source on EVERY build,
      // and a token burst rebuilds this bubble dozens of times a second —
      // that storm froze the whole app on Redmi. While typing, render a
      // plain growing Text (or thinking dots before the first token); the
      // bubble switches to the full markdown once the stream completes.
      return _buildStreamingBubble(context, message, scheme);
    }
    final key = _cacheKeyFor(message, scheme);
    if (_cacheKey != key || _cachedChild == null) {
      _cacheKey = key;
      _cachedChild = _buildBubble(context, message, scheme);
    }
    return _cachedChild!;
  }

  /// The live typing bubble: same assistant shell, cheap growing text.
  Widget _buildStreamingBubble(
    BuildContext context,
    AiMessageUi message,
    ColorScheme scheme,
  ) {
    final shell = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.secondaryContainer.withValues(alpha: 0.55),
          scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        ],
      ),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(16),
      ),
      border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: shell,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.content.isEmpty)
              const _ThinkingDots()
            else
              Text(
                message.content,
                style: TextStyle(
                  color: scheme.onSurface,
                  height: 1.4,
                  fontSize: 13.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(
    BuildContext context,
    AiMessageUi message,
    ColorScheme scheme,
  ) {
    // Reward messages: a centered celebration pill with a gradient rim —
    // clearly distinct from user/assistant bubbles.
    if (message.role == 'reward') {
      final lines = message.content.split('\n');
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primaryContainer.withValues(alpha: 0.9),
                scheme.tertiaryContainer.withValues(alpha: 0.75),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lines.first,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (lines.length > 1) ...[
                      const SizedBox(height: 2),
                      Text(
                        lines.sublist(1).join('\n'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isUser = message.role == 'user';
    final isAda = !isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          gradient: isAda
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.secondaryContainer.withValues(alpha: 0.55),
                    scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  ],
                )
              : null,
          color: isUser ? scheme.primary : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isAda
              ? Border.all(
                  color: scheme.primary.withValues(alpha: 0.22),
                )
              : null,
        ),
        // Assistant messages render real markdown (lists, bold, code blocks
        // from the JSON commands); user messages stay plain selectable text.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAda)
              MarkdownBody(
                data: message.content,
                selectable: true,
                softLineBreak: true,
                // Clean Cut/Copy/Paste/Share toolbar (no "Ask Copilot" /
                // web lookup on Android).
                contextMenuBuilder: (ctx, state) =>
                    buildLimitedContextMenu(ctx, state),
                styleSheet: MarkdownStyleSheet.fromTheme(
                  Theme.of(context),
                ).copyWith(
                  p: TextStyle(
                    color: scheme.onSurface,
                    height: 1.4,
                    fontSize: 13.5,
                  ),
                  listBullet: TextStyle(
                    color: scheme.primary,
                    fontSize: 13.5,
                  ),
                  code: TextStyle(
                    color: scheme.primary,
                    fontSize: 12.5,
                    backgroundColor: scheme.primaryContainer
                        .withValues(alpha: 0.4),
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
            else
              SelectableText(
                message.content,
                style: TextStyle(
                  color: isUser ? scheme.onPrimary : scheme.onSurface,
                  height: 1.4,
                  fontSize: 13.5,
                ),
                // No selection loupe and a clean toolbar (Cut/Copy/Paste/
                // Share only — no "Ask Copilot" / web lookup on Android).
                magnifierConfiguration: TextMagnifierConfiguration.disabled,
                contextMenuBuilder: (ctx, state) =>
                    buildLimitedContextMenu(ctx, state),
              ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool enabled;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                cursorOpacityAnimates: true,
                controller: controller,
                focusNode: focusNode,
                maxLines: 4,
                minLines: 1,
                // Hard cap (no visible counter): 13 000 characters. Hyphens
                // typed as punctuation become em dashes automatically.
                inputFormatters: [
                  LengthLimitingTextInputFormatter(13000),
                  const EmDashInputFormatter(),
                ],
                // Disable autocorrect/spellcheck: on Android it draws yellow
                // squiggly underlines under Russian words inside the chat.
                autocorrect: false,
                enableSuggestions: false,
                spellCheckConfiguration:
                    const SpellCheckConfiguration.disabled(),
                // No magnifying-glass selection loupe + a clean toolbar with
                // only Cut/Copy/Paste/Share (no "Ask Copilot" / lookup).
                magnifierConfiguration: TextMagnifierConfiguration.disabled,
                contextMenuBuilder: (ctx, state) =>
                    buildLimitedContextMenu(ctx, state),
                onSubmitted: (_) => enabled ? onSend() : null,
                decoration: InputDecoration(
                  hintText: L.tr(context, 'aiInputHint'),
                  isDense: true,
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Gradient send button — theme-aware (was hardcoded purple).
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, scheme.tertiary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: enabled ? onSend : null,
                icon: const Icon(Icons.send_rounded, size: 20),
                color: scheme.onPrimary,
                // The pressed/ripple highlight must follow the circle of
                // the gradient shell exactly — the default square-ish
                // highlight sticks out of the round button.
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tiny three-dot typing indicator shown inside the streaming bubble
/// before the model's first token lands. Cheap: one controller, staggered
/// sine opacity — no per-token rebuilds.
class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Opacity(
                  opacity:
                      0.35 + 0.65 * (0.5 + 0.5 * math.sin(2 * math.pi * ((t + i / 3) % 1) - math.pi / 2)),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
