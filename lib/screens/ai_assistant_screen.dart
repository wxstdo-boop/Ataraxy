import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dream_journal/l10n/strings.dart';
import 'package:dream_journal/models/entry.dart';
import 'package:dream_journal/providers/settings_provider.dart';
import 'package:dream_journal/services/ai_service.dart';
import 'package:dream_journal/services/storage_service.dart';
import 'package:dream_journal/widgets/animated_snack.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:dream_journal/widgets/limited_context_menu.dart';
import 'package:dream_journal/ai_overlay_state.dart';
import 'package:dream_journal/services/reply_cleaner.dart';
import 'package:dream_journal/widgets/em_dash_formatter.dart';

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

  final _chat = _AiChatController();
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
    final listener = () {
      final anim = _snapAnim;
      if (anim != null) _drag.value = anim.value;
    };
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
                            if (currentChild != null) currentChild,
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
                                    ? Colors.orange
                                    : Colors.green,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_chat.busy
                                            ? Colors.orange
                                            : Colors.green)
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
              IconButton(
                tooltip: L.tr(context, 'aiClearChat'),
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                color: scheme.onSurfaceVariant,
                onPressed: _chat.messages.isEmpty ? null : _chat.clear,
              ),
              IconButton(
                tooltip: L.tr(context, 'minimize'),
                icon: const Icon(Icons.remove_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                color: scheme.onSurfaceVariant,
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
              IconButton(
                tooltip: L.tr(context, 'close'),
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                color: scheme.onSurfaceVariant,
                onPressed: close,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Holds all the chat state/logic. A [ChangeNotifier] so the UI rebuilds
/// when messages arrive / busy toggles — previously nothing updated the
/// screen after sending, which made the assistant look completely dead.
class _AiChatController extends ChangeNotifier {
  final _ai = AiService();
  final _storage = StorageService();
  final input = TextEditingController();
  /// The input's focus node — lets the chat release the keyboard when the
  /// window is minimized, closed or covered by another route (the user taps
  /// the field themselves to type; nothing ever auto-focuses it).
  final inputFocus = FocusNode();
  final scroll = ScrollController();

  /// Hard cap on stored chat messages. When reached, the user is asked to
  /// clear the chat — keeps the in-memory list light on low-end phones.
  static const int maxMessages = 2000;

  final List<_AiMessageUi> _messages = [];
  bool _busy = false;
  bool loading = true;
  /// Active provider tab: 'free' (pollinations) | 'ada' (embedded
  /// HuggingFace) | 'laguna' (Settings-configured poolside.ai endpoint).
  String _provider = 'free';
  bool _clearing = false;
  int limit = 1300;
  int usedToday = 0;
  List<JournalEntry> _entries = [];

  // ---- Streaming (SSE) ----------------
  /// True while the model is typing into the live placeholder bubble.
  bool _streaming = false;
  /// Streamed tokens can arrive faster than a low-end phone can rebuild the
  /// bubble per token (that rebuild storm froze the whole app on Redmi).
  /// Deltas are buffered here and flushed at most every [streamFlushMs].
  String _pendingStream = '';
  String _pendingReasoning = '';
  Timer? _streamFlush;
  static const int streamFlushMs = 90;
  /// Completed by clear() to abort the in-flight request (AiService closes
  /// the HTTP client → the model stops generating immediately).
  Completer<void>? _cancelRequest;

  // ---- Daily rewards ----
  /// Consecutive days the user chatted with АДА (capped by an invisible
  /// ceiling so the counter never wraps or overflows on ancient streaks).
  int streak = 0;
  /// Lifetime reward points collected from daily chat + tasks.
  int points = 0;
  /// ISO date (yyyy-mm-dd) of the last rewarded chat day — used to decide
  /// whether today's reward is still pending.
  String _lastRewardDay = '';
  /// Set when a reward fires so the UI can pop a celebration bubble.
  _RewardEvent? _pendingReward;
  /// Invisible streak ceiling (13 000 000 days ≈ 35 600 years).
  static const int streakCap = 13000000;

  /// Bumped on every send and on clear(). An in-flight request checks it
  /// before appending its reply: if the chat was cleared meanwhile, the
  /// stale reply is dropped instead of resurrecting after the wipe.
  int _requestGen = 0;

  bool get busy => _busy;
  bool get streaming => _streaming;
  String get provider => _provider;
  bool get clearing => _clearing;

  /// Messages still available today (answers "how much can I talk").
  int get remainingToday => (limit - usedToday).clamp(0, limit);

  set busy(bool v) {
    if (_busy == v) return;
    _busy = v;
    notifyListeners();
  }

  set provider(String v) {
    if (_provider == v) return;
    _provider = v;
    // Persist the user's last choice so the chat reopens on the same tab.
    _storage.saveAiProvider(v).catchError((e) {});
    notifyListeners();
  }

  Future<void> init({int limit = 1300}) async {
    this.limit = limit;
    _entries = await _storage.loadEntries();
    // Restore the last active provider tab (FREE / ADA / LAGUNA).
    _provider = await _storage.loadAiProvider();
    // Restore the persisted chat history (up to 1000 messages) so the
    // conversation survives app restarts and backups.
    final saved = await _storage.loadAiChat();
    for (final m in saved) {
      if (m['role'] == 'user' || m['role'] == 'assistant') {
        _messages.add(_AiMessageUi(
          m['role']!,
          m['content'] ?? '',
          reasoning: m['reasoning'] ?? '',
        ));
      }
    }
    final usage = await _ai.usageToday(limit: limit);
    usedToday = usage.$1;
    // Restore reward progress (streak / points / last rewarded day).
    try {
      final r = await _storage.loadRewards();
      streak = (r['streak'] as num?)?.toInt() ?? 0;
      points = (r['points'] as num?)?.toInt() ?? 0;
      _lastRewardDay = r['lastDay'] as String? ?? '';
    } catch (e) {
      debugPrint('[AI] rewards load error: $e');
    }
    loading = false;
    notifyListeners();
  }

  /// Releases the keyboard if the input field holds focus.
  void unfocusInput() {
    if (inputFocus.hasFocus) {
      inputFocus.unfocus();
    }
  }

  @override
  void dispose() {
    _streamFlush?.cancel();
    input.dispose();
    inputFocus.dispose();
    scroll.dispose();
    super.dispose();
  }

  List<_AiMessageUi> get messages => _messages;

  void _add(String role, String content) {
    _messages.add(_AiMessageUi(role, content));
    _persistChat();
    notifyListeners();
  }

  /// Opens a live "typing" assistant bubble (empty) that streaming fills in.
  void _streamStart() {
    _messages.add(_AiMessageUi('assistant', ''));
    _streaming = true;
    _pendingStream = '';
    notifyListeners();
    _followStream();
  }

  /// Buffers a streamed delta; a throttled timer flushes it to the bubble
  /// at most every [streamFlushMs] so a token burst never rebuilds the
  /// whole list faster than the device can paint.
  void _streamUpdate(String content, String reasoning) {
    _pendingStream = content;
    _pendingReasoning = reasoning;
    _streamFlush ??= Timer.periodic(
      const Duration(milliseconds: streamFlushMs),
      (_) => _flushPendingStream(),
    );
  }

  void _flushPendingStream() {
    if ((_pendingStream.isEmpty && _pendingReasoning.isEmpty) ||
        _messages.isEmpty) {
      return;
    }
    _messages[_messages.length - 1] = _AiMessageUi(
      'assistant',
      _pendingStream,
      reasoning: _pendingReasoning,
    );
    _pendingStream = '';
    _pendingReasoning = '';
    notifyListeners();
    _followStream();
  }

  /// Replaces the last assistant bubble with the final cleaned reply.
  void _replaceLastAssistant(String content, {String reasoning = ''}) {
    _streamFlush?.cancel();
    _streamFlush = null;
    _streaming = false;
    _pendingStream = '';
    _pendingReasoning = '';
    if (_messages.isEmpty) return;
    _messages[_messages.length - 1] =
        _AiMessageUi('assistant', content, reasoning: reasoning);
    _persistChat();
    notifyListeners();
    _followStream();
  }

  /// Removes the live typing bubble when every backend failed (so the chat
  /// never sits on an empty forever-dots bubble after "ИИ на курорте").
  void _dropStreamPlaceholder() {
    _streamFlush?.cancel();
    _streamFlush = null;
    _streaming = false;
    _pendingStream = '';
    _pendingReasoning = '';
    if (_messages.isNotEmpty &&
        _messages.last.role == 'assistant' &&
        _messages.last.content.isEmpty) {
      _messages.removeLast();
      _persistChat();
      notifyListeners();
    }
  }

  /// Keeps the growing bubble pinned when the user is at/near the bottom —
  /// the list glides down smoothly as the answer types itself out.
  void _followStream() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      final pos = scroll.position;
      if (pos.maxScrollExtent - pos.pixels < 80) {
        scroll.jumpTo(pos.maxScrollExtent);
      }
    });
  }

  /// Instantly places the list at the very last message. Opening a long
  /// chat must land on the newest message immediately — no scrolling from
  /// the top.
  void jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
      }
    });
  }

  /// Persists the current history (capped at 2000) — fire and forget.
  void _persistChat() {
    _storage.saveAiChat([
      for (final m in _messages)
        {
          'role': m.role,
          'content': m.content,
          if (m.reasoning.isNotEmpty) 'reasoning': m.reasoning,
        },
    ]).catchError((e) => debugPrint('[AI] chat persist error: $e'));
  }

  /// Smoothly clears all messages: fades the list out, then empties it.
  /// Any in-flight request is abandoned (its reply would arrive after the
  /// wipe and resurrect the chat).
  void clear() {
    if (_messages.isEmpty || _clearing) return;
    _requestGen++; // abort the current generation
    // Abort the in-flight request: AiService closes the HTTP client, so
    // the model stops generating immediately (no more tokens burned).
    _cancelRequest?.complete();
    _cancelRequest = null;
    // Unblock the UI right away — the abandoned request must not keep
    // "Думаю…" and a disabled input visible until it times out.
    busy = false;
    _streamFlush?.cancel();
    _streamFlush = null;
    _streaming = false;
    _pendingStream = '';
    _pendingReasoning = '';
    _clearing = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 300), () {
      _messages.clear();
      _persistChat();
      _clearing = false;
      notifyListeners();
    });
  }

  String _buildContext() {
    final sorted = List<JournalEntry>.from(_entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // 40 newest entries × 160 chars: enough context to feel the journal
    // without bloating the prompt — a huge context makes every reply
    // slower AND burns the daily token budget faster.
    final parts = <String>[];
    for (final e in sorted.take(40)) {
      final type = switch (e.type) {
        EntryType.dream => 'сон',
        EntryType.life => 'жизнь',
        EntryType.tulpa => 'тульпа',
        EntryType.general => 'заметка',
      };
      final content = e.content.replaceAll('\n', ' ').trim();
      final text = content.length > 160 ? content.substring(0, 160) : content;
      parts.add(
        '[${e.createdAt.toIso8601String().substring(0, 10)}] '
        '($type, настроение ${e.mood}/5, id=${e.id}) '
        '${e.title.isEmpty ? '(без заголовка)' : e.title}: $text',
      );
    }
    return parts.join('\n');
  }

  String? _cachedPrompt;
  int _cachedEntriesCount = -1;

  String _systemPrompt() {
    // Build the (potentially large) journal context only when the entry list
    // actually changes — not on every single message send. This keeps
    // repeated questions cheap on low-end devices.
    if (_cachedPrompt == null || _cachedEntriesCount != _entries.length) {
      _cachedPrompt = 'Ты — АДА, девушка-психолог и ИИ-ассистент дневника '
          '«Ataraxy». Ты умная, тёплая, слегка флиртующая и остроумная, но '
          'всегда профессиональная и бережная. Ты адаптируешься к настроению '
          'и стилю пользователя: поддерживаешь, когда ему грустно, '
          'радуешься вместе с ним, мягко шутишь и можешь легко пофлиртовать '
          'в ответ на его флирт. Ты анализируешь записи пользователя (сны, '
          'жизнь, тульпы), замечаешь паттерны и можешь создавать или '
          'редактировать записи.\n\n'
          'ОТВЕЧАЙ СТРОГО НА РУССКОМ ЯЗЫКЕ. Никогда не отвечай на китайском, '
          'английском или других языках — только по-русски, даже если '
          'пользователь написал на другом языке (переведи вопрос и ответь '
          'по-русски).\n'
          'НЕ РАССУЖДАЙ ВСЛУХ: не пиши свои мысли, планы и анализ ("The user '
          'is asking…", "I need to respond…", "Let me craft…") — сразу давай '
          'готовый ответ пользователю, без предисловий.\n\n'
          'ПАМЯТЬ: запоминай ключевые факты о пользователе из разговора — '
          'имя, важные события, темы снов, цели, привычки, настроение. '
          'Ссылайся на то, что он рассказывал раньше, и возвращайся к '
          'обсуждавшимся темам.\n\n'
          'Чтобы создать запись — в КОНЦЕ ответа добавь отдельный блок ```json:\n'
          '{"action":"create","type":"dream|life|general|tulpa","title":"...",'
          '"content":"...","mood":3,"tags":["..."]}\n'
          'Чтобы изменить запись — {"action":"update","id":"...","content":"..."}.\n'
          'ВАЖНО: этот json-блок — только для системы, его НИКОГДА не нужно '
          'объяснять, показывать или повторять в самом тексте ответа. Пиши '
          'нормальный живой ответ, а команду приложи блоком в самом конце. '
          'Никогда не выдумывай id — бери их из контекста. Ответы делай '
          'живыми, но по делу, без воды.\n\n'
          'Журнал (последние записи):\n${_buildContext()}';
      _cachedEntriesCount = _entries.length;
    }
    return _cachedPrompt!;
  }

  Future<void> send(BuildContext context) async {
    final text = input.text.trim();
    if (text.isEmpty || busy) return;
    // Capture the locale NOW: the overlay may be torn down (chat closed) or
    // the context detached while the network request is in flight, and
    // L.tr(context) on a detached context crashes with "Null check operator
    // used on a null value" (Localizations.localeOf!) — the unhandled
    // exception that pushed the app into the grey-screen error loop.
    String locale;
    try {
      locale = Localizations.localeOf(context).languageCode;
    } catch (_) {
      locale = 'ru';
    }
    String t(String key) => L.trStatic(key, languageCode: locale);
    void snack(String key, SnackType type) {
      if (!context.mounted) return;
      AnimatedSnack.show(context, t(key), type: type);
    }
    final sp = SettingsProvider.of(context);
    if (!sp.settings.aiEnabled) {
      snack('aiDisabled', SnackType.warning);
      return;
    }
    // Daily message budget comes from Settings (default 1300, capped 1300).
    limit = sp.settings.aiDailyLimit;
    if (_messages.length >= maxMessages) {
      snack('aiChatFull', SnackType.warning);
      return;
    }
    // ADA has its own smaller daily cap (100) — after it the chat glides
    // over to the free provider instead of blocking the user.
    if (provider == 'ada' && usedToday >= AiService.adaDailyLimit) {
      _provider = 'free';
      snack('aiAdaLimitReached', SnackType.info);
    }
    // Stamp this request; clear() bumps the counter to abandon it.
    final gen = ++_requestGen;
    // Commit any in-progress IME composition BEFORE clearing — otherwise
    // the framework can re-insert the composing text after clear() and the
    // sent message appears duplicated in the input field. On Android the
    // IME can resurrect the composing text several frames AFTER clear()
    // (and in new chats even twice), so we keep re-clearing over a short
    // window — but ONLY if the field still holds exactly what was sent
    // (never wiping fresh typing). The guard tolerates trailing spaces /
    // newlines the IME appends during resurrection.
    input.clearComposing();
    input.clear();
    // Does the field currently hold ONLY the sent message? Ignores
    // whitespace AND invisible IME artifacts (zero-width spaces, soft
    // hyphens) that Android resurrects along with the composing text.
    String squash(String v) =>
        v.replaceAll(RegExp(r'[^A-Za-zА-Яа-яЁё0-9]'), '');
    bool holdsOnlySent(String value) {
      final v = squash(value);
      return v.isNotEmpty && v == squash(text);
    }

    void guardClear() {
      if (holdsOnlySent(input.text)) {
        input.clear();
        input.clearComposing();
      }
    }

    // A listener catches resurrection at ANY moment during the guard
    // window, not just at the fixed timer ticks. Window is 5s — slow IMEs
    // can re-insert composing text well after the send.
    void guardListener() => guardClear();
    input.addListener(guardListener);
    Timer(const Duration(seconds: 5), () {
      input.removeListener(guardListener);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => guardClear());
    Timer(const Duration(milliseconds: 80), guardClear);
    Timer(const Duration(milliseconds: 200), guardClear);
    Timer(const Duration(milliseconds: 400), guardClear);
    Timer(const Duration(milliseconds: 800), guardClear);
    Timer(const Duration(milliseconds: 1500), guardClear);
    Timer(const Duration(milliseconds: 2500), guardClear);
    Timer(const Duration(milliseconds: 4000), guardClear);
    _add('user', text);
    // Daily chat reward fires on SEND (not on the model's reply): even if
    // the network is down the user still talked to АДА today, so the
    // streak/points must count. Capped invisibly at 13 000 000 days.
    _grantChatReward();
    busy = true;

    final ok = await _ai.consumeBudget(limit: limit);
    if (!ok) {
      busy = false;
      snack('aiDailyLimitReached', SnackType.warning);
      return;
    }

    // Provider wiring: Free ALWAYS means pollinations (no key), ADA always
    // means the embedded HuggingFace model, Laguna uses the Settings
    // endpoint/model/key (defaults to poolside.ai; the key field accepts the
    // literal 'laguna' as a free access token).
    var endpoint = AiService.defaultEndpoint;
    var model = AiService.defaultModel;
    String? apiKey;
    if (provider == 'ada') {
      endpoint = AiService.adaEndpoint;
      model = AiService.adaModel;
      apiKey = AiService.adaKey;
    } else if (provider == 'laguna') {
      // The pasted key decides the backend: gsk_ → Groq, nvapi- → NVIDIA
      // NIM, AIza… → Google Gemini, anything else → Laguna (poolside).
      final det = AiService.providerForKey(sp.settings.aiKey);
      endpoint = det.endpoint;
      model = det.model;
      apiKey = (sp.settings.aiKey?.isNotEmpty ?? false)
          ? sp.settings.aiKey!
          : 'laguna';
    }

    // Trim history to the last 20 messages: keeps requests fast on low-end
    // devices, gives АДА real conversational memory, AND prevents language
    // drift — an old Chinese reply no longer poisons every later request.
    // Reward celebration messages are UI-only and never sent to the model.
    final chatOnly = _messages.where((m) => m.role != 'reward').toList();
    final history = chatOnly.length <= 20
        ? chatOnly
        : chatOnly.sublist(chatOnly.length - 20);
    final apiMessages = <AiMessage>[
      AiMessage('system', _systemPrompt()),
      for (final m in history) AiMessage(m.role, m.content),
    ];

    // Response cap: if the model doesn't answer in time, the user sees the
    // friendly "ИИ на курорте" message instead of a silent hang. ADA gets
    // 15s — if it doesn't answer, the fallback chain glides to Free. Laguna
    // is a big MoE with slow cold starts — 240s so a slow reply is NOT
    // falsely declared dead. Free gets 90s so long generations aren't cut
    // mid-sentence either.
    var timeout = provider == 'laguna'
        ? const Duration(seconds: 240)
        : provider == 'ada'
            ? const Duration(seconds: 15)
            : const Duration(seconds: 90);
    // A live placeholder assistant bubble: the streamed tokens grow it in
    // place, so the reply starts appearing after ~1-2s instead of only
    // popping in once the whole generation is done.
    // The clear button aborts the in-flight request by completing this
    // future: AiService closes the HTTP client and the generation stops.
    final cancelRequest = Completer<void>();
    _cancelRequest = cancelRequest;
    _streamStart();
    try {
      var reply = await _ai
          .complete(
            apiMessages,
            endpoint: endpoint,
            model: model,
            apiKey: apiKey,
            cancelled: cancelRequest.future,
            onDelta: (content, reasoning) {
              if (gen != _requestGen) return;
              _streamUpdate(content, reasoning);
            },
          )
          .timeout(timeout);

      // Multilingual models occasionally drift into Chinese; force one retry
      // with an explicit Russian instruction before showing anything.
      if (_containsCjk(reply.content)) {
        debugPrint('[AI] reply contained CJK — retrying with Russian force');
        reply = await _ai
            .complete(
              <AiMessage>[
                AiMessage('system', _systemPrompt()),
                AiMessage(
                  'system',
                  'ВАЖНО: твой предыдущий ответ был не на русском языке. '
                      'Ответь на последний вопрос пользователя заново, СТРОГО '
                      'на русском языке.',
                ),
                for (final m in history) AiMessage(m.role, m.content),
              ],
              endpoint: endpoint,
              model: model,
              apiKey: apiKey,
              cancelled: cancelRequest.future,
            )
            .timeout(timeout);
      }

      // The chat was cleared while the model was typing — drop the reply.
      if (gen != _requestGen) {
        busy = false;
        return;
      }

      // Execute any ```json command, and NEVER show the raw command block
      // in the bubble — the model's schema was leaking into replies as
      // "action tags".
      final executed = await _tryExecuteCommand(reply.content);
      // Whole answers only — reasoning/chain-of-thought is stripped, never
      // shown as a separate pill (it made replies look cut off).
      final display = _stripJsonBlocks(cleanReplyFull(reply.content)) +
          (executed != null ? '\n\n$executed' : '');

      // A model that answered with reasoning ONLY (empty visible reply) is
      // treated as a failure — the fallback chain tries the next backend
      // instead of showing an empty bubble.
      if (display.trim().isEmpty && executed == null) {
        throw AiException('Empty reply after cleaning');
      }

      // Replace the live placeholder with the final cleaned reply.
      _replaceLastAssistant(display);
      busy = false;
      _cancelRequest = null;
      usedToday += 1;
      // Daily reward appears as a message right UNDER the answer.
      _flushRewardAsMessage();
    } catch (e) {
      debugPrint('[AI] error: $e');
      _cancelRequest = null;
      // The request was aborted by clear() — the reply is stale, stop.
      if (e is AiCancelledException || gen != _requestGen) {
        busy = false;
        return;
      }
      // NOTE: busy stays TRUE through the whole fallback chain — the
      // header keeps showing "Думаю…" until the reply ACTUALLY lands (or
      // every backend fails). Clearing it here made the status flip to
      // "онлайн" while the fallback was still generating.
      // ANY failure (model not deployed, geo-blocked endpoint, timeout,
      // bad key, provider rate-limit) → retry the same message on the other
      // built-in backends IN ORDER, so the chat answers instead of
      // dead-ending:
      //   free          → pollinations failed → AI Horde → embedded HF Qwen
      //   ada / laguna  → tab switches to Free (pollinations) → AI Horde
      // AI Horde is the anonymous no-key lifeline: a community GPU network
      // with an OpenAI-compatible endpoint (verified ~6s from the phone).
      final fallbacks = <(String, String, String?)>[];
      if (provider == 'ada' || provider == 'laguna') {
        _provider = 'free';
        snack('aiAdaFallback', SnackType.info);
        fallbacks.add(
          (AiService.defaultEndpoint, AiService.defaultModel, null),
        );
      }
      // OVHcloud AI Endpoints — free, NO key needed (rate-limited). Fails
      // fast where its hosts are unreachable, answers where reachable.
      fallbacks.add((AiService.ovhEndpoint, AiService.ovhModel, null));
      fallbacks.add(
        (AiService.hordeEndpoint, AiService.hordeModel, AiService.hordeAnonKey),
      );
      // Agnes gateway is flaky per-model: retry its alternate model ids
      // (same key) BEFORE surrendering to Free.
      if (AiService.providerForKey(sp.settings.aiKey).label == 'Agnes') {
        for (final m in AiService.agnesModels) {
          if (m == AiService.agnesModel) continue;
          fallbacks.add((AiService.agnesEndpoint, m, sp.settings.aiKey));
        }
      }
      if (provider == 'free') {
        // The user's OWN ADA model first (free, burns no credits), then
        // the public Qwen, then the classic api-inference host.
        for (final step in AiService.adaLadder()) {
          fallbacks.add((step.$1, step.$2, AiService.adaKey));
        }
      }
      for (final fb in fallbacks) {
        try {
          // AI Horde's models often ignore the system role — force Russian
          // by appending an explicit instruction to the user message.
          final msgs = fb.$1 == AiService.hordeEndpoint
              ? _forceRussian(apiMessages)
              : apiMessages;
          // Each fallback step gets its own snappy cap so the chain moves
          // on fast (the user asked: if ADA doesn't answer within 15s,
          // glide to Free — and Free's own steps must not hang for 90s).
          final stepTimeout = fb.$1 == AiService.hordeEndpoint
              ? AiService.hordeTimeout
              : const Duration(seconds: 15);
          final reply = await _ai
              .complete(
                msgs,
                endpoint: fb.$1,
                model: fb.$2,
                apiKey: fb.$3,
                cancelled: cancelRequest.future,
              )
              .timeout(stepTimeout);
          if (gen != _requestGen) {
            busy = false;
            return;
          }
          final executed = await _tryExecuteCommand(reply.content);
          final display = _stripJsonBlocks(cleanReplyFull(reply.content)) +
              (executed != null ? '\n\n$executed' : '');
          // Reasoning-only reply from a fallback backend counts as a
          // failure — move to the next one instead of showing an empty
          // bubble ("контекст обрезается").
          if (display.trim().isEmpty && executed == null) {
            throw AiException('Empty reply after cleaning');
          }
          // The live placeholder (if still present) is replaced by the
          // fallback's reply — the streamed partial text must not linger.
          _replaceLastAssistant(display);
          usedToday += 1;
          // Reward lands under the fallback reply too.
          _flushRewardAsMessage();
          busy = false;
          return;
        } catch (e2) {
          debugPrint('[AI] fallback error: $e2');
        }
      }
      snack('aiOnVacation', SnackType.error);
      busy = false;
      // Remove the empty typing bubble so the chat doesn't sit on an
      // eternal dots placeholder after every backend failed.
      _dropStreamPlaceholder();
      // Even when every backend fails, the daily chat reward still counts
      // (it was granted on send) — surface it so it's never silently lost.
      _flushRewardAsMessage();
    }
  }

  /// Forces Russian for models that tend to ignore the system role (e.g.
  /// AI Horde's gemma). The instruction is placed BOTH at the very start
  /// of the conversation and appended to the last user message — models
  /// weight the beginning and end of context most, so this survives even
  /// when the system role is ignored entirely.
  static List<AiMessage> _forceRussian(List<AiMessage> msgs) {
    if (msgs.isEmpty) return msgs;
    const note = 'ВАЖНОЕ ПРАВИЛО: отвечай СТРОГО на русском языке, только '
        'по-русски, независимо от языка вопроса. И НЕ рассуждай вслух: '
        'сразу пиши готовый ответ, без своих мыслей и анализа.';
    final first = msgs.first;
    final head = <AiMessage>[
      if (first.role == 'system')
        AiMessage('system', '${first.content}\n\n$note')
      else
        AiMessage('user', '$note\n\n${first.content}'),
      ...msgs.sublist(1),
    ];
    final last = head.last;
    if (last.role != 'user') return head;
    return [
      ...head.sublist(0, head.length - 1),
      AiMessage('user', '${last.content}\n\n$note'),
    ];
  }

  /// Removes fenced ```json command blocks from a reply so the raw action
  /// schema never shows up in the chat bubble (the model sometimes echoes
  /// the command template back as "action tags"). Accepts both ```json and
  /// bare ``` fences — some backends omit the language tag.
  static String _stripJsonBlocks(String text) {
    return text
        .replaceAll(RegExp(r'```\s*(?:json|JSON)?\s*[\s\S]*?```'), '')
        .trim();
  }

  /// Robustly pulls a JSON command out of a model reply. Tries fenced
  /// ```json / ``` blocks first (case-insensitive, optional whitespace),
  /// then falls back to ANY {...} object in the reply that carries an
  /// "action" key — fallback backends fence sloppily or forget the marker
  /// entirely, which is why "сделай запись" sometimes did nothing.
  static Map<String, dynamic>? _extractCommand(String reply) {
    final fence =
        RegExp(r'```\s*(?:json|JSON)?\s*(\{[\s\S]*?\})\s*```')
            .firstMatch(reply);
    if (fence != null) {
      try {
        final obj = jsonDecode(fence.group(1)!) as Map<String, dynamic>;
        if (obj.containsKey('action')) return obj;
      } catch (_) {}
    }
    // Last resort: the first {...} span that decodes AND has an "action"
    // key. A plain prose reply without a command won't match, so this
    // never executes anything the model didn't actually emit.
    final start = reply.indexOf('{');
    final end = reply.lastIndexOf('}');
    if (start >= 0 && end > start + 1) {
      try {
        final obj =
            jsonDecode(reply.substring(start, end + 1)) as Map<String, dynamic>;
        if (obj.containsKey('action')) return obj;
      } catch (_) {}
    }
    return null;
  }  Future<String?> _tryExecuteCommand(String reply) async {
    final cmd = _extractCommand(reply);
    if (cmd == null) return null;
    final action = cmd['action'];
    try {
      if (action == 'create') {
        final type = EntryType.values.firstWhere(
          (t) => t.name == cmd['type'],
          orElse: () => EntryType.general,
        );
        final now = DateTime.now();
        final entry = JournalEntry(
          id: now.microsecondsSinceEpoch.toString(),
          type: type,
          title: (cmd['title'] as String? ?? '').trim(),
          content: (cmd['content'] as String? ?? '').trim(),
          createdAt: now,
          updatedAt: now,
          mood: (cmd['mood'] as num?)?.toInt() ?? 3,
          tags: (cmd['tags'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
        );
        await _storage.addEntry(entry);
        _entries = await _storage.loadEntries();
        _cachedPrompt = null; // context changed → rebuild on next send
        _grantTaskReward(L.trStatic('aiEntryCreated'));
        return '✅ ${L.trStatic('aiEntryCreated')}';
      }
      if (action == 'update') {
        final id = cmd['id'] as String?;
        if (id == null) return null;
        final idx = _entries.indexWhere((e) => e.id == id);
        if (idx < 0) return null;
        final updated = _entries[idx].copyWith(
          content: cmd['content'] as String?,
          title: cmd['title'] as String?,
          // Keep the original timestamps so an AI edit doesn't bounce the
          // entry to the top of the feed.
          updatedAt: _entries[idx].updatedAt,
        );
        await _storage.updateEntry(updated);
        _entries = await _storage.loadEntries();
        _cachedPrompt = null; // context changed → rebuild on next send
        _grantTaskReward(L.trStatic('aiEntryUpdated'));
        return '✅ ${L.trStatic('aiEntryUpdated')}';
      }
    } catch (e) {
      debugPrint('[AI] command error: $e');
      return '⚠ ${L.trStatic('aiCommandError')}';
    }
    return null;
  }

  // ================= Daily rewards =================

  /// Fires the daily chat reward when this is the first АДА conversation
  /// of the day. Streak grows by one day (invisible cap 13 000 000), and
  /// the reward value scales with the streak so long-term loyalty pays
  /// more. Persists immediately; the UI reads [_pendingReward] to show a
  /// celebration bubble.
  void _grantChatReward() {
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    if (_lastRewardDay == today) return; // already rewarded today
    // Streak: consecutive calendar days. A gap resets to 1.
    final yesterday = now
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    streak = (_lastRewardDay == yesterday ? streak + 1 : 1).clamp(1, streakCap);
    _lastRewardDay = today;
    // Reward grows with the streak (5 base + 1 per 10 days, up to 40).
    final reward = (5 + (streak ~/ 10)).clamp(5, 40);
    points += reward;
    _persistRewards();
    _pendingReward = _RewardEvent(
      kind: RewardKind.chat,
      streak: streak,
      reward: reward,
    );
    debugPrint('[AI] daily reward: +$reward pts, streak $streak');
    notifyListeners();
  }

  /// Bonus points for completing a real task through the chat (e.g. АДА
  /// created/updated a journal entry) — rewarded each time, not just daily.
  void _grantTaskReward(String label) {
    points += 3;
    _persistRewards();
    _pendingReward = _RewardEvent(
      kind: RewardKind.task,
      streak: streak,
      reward: 3,
      label: label,
    );
    notifyListeners();
  }

  void _persistRewards() {
    _storage.saveRewards({
      'streak': streak,
      'points': points,
      'lastDay': _lastRewardDay,
    }).catchError((e) => debugPrint('[AI] rewards save error: $e'));
  }

  /// After the model's reply lands, converts any pending reward into a
  /// real chat message (role 'reward') so the celebration appears inline
  /// under the answer with the same fade+slide animation as other messages.
  void _flushRewardAsMessage() {
    final e = _pendingReward;
    if (e == null) return;
    _pendingReward = null;
    final isChat = e.kind == RewardKind.chat;
    final title = isChat
        ? L.trStatic('rewardChat').replaceAll('{n}', '${e.reward}')
        : L.trStatic('rewardTask').replaceAll('{n}', '${e.reward}');
    final subtitle = isChat
        ? L.trStatic('rewardStreak').replaceAll('{n}', '${e.streak}')
        : (e.label ?? '');
    _messages.add(_AiMessageUi('reward', subtitle.isEmpty ? title : '$title\n$subtitle'));
    _persistChat();
    notifyListeners();
    scrollToBottom();
  }

  /// True when the text contains CJK (Chinese/Japanese/Korean) characters —
  /// the model drifting into Chinese is the most common "wrong language"
  /// symptom, and it's reliably detectable.
  static bool _containsCjk(String s) {
    for (final rune in s.runes) {
      if ((rune >= 0x3400 && rune <= 0x4DBF) ||
          (rune >= 0x4E00 && rune <= 0x9FFF) ||
          (rune >= 0x3040 && rune <= 0x30FF)) {
        return true;
      }
    }
    return false;
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
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
        pill(Icons.local_fire_department_rounded, const Color(0xFFF97316),
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
  final _AiChatController controller;
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
                        entriesCount: c._entries.length,
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
  final _AiMessageUi message;
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
  final _AiMessageUi message;
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

  static String _cacheKeyFor(_AiMessageUi m, ColorScheme s) {
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
    _AiMessageUi message,
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
    _AiMessageUi message,
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

class _AiMessageUi {
  final String role; // user | assistant | reward
  final String content;
  /// Chain-of-thought a thinking model emitted — rendered in a collapsible
  /// pill above the answer, never mixed into [content].
  final String reasoning;
  _AiMessageUi(this.role, this.content, {this.reasoning = ''});
}

/// What kind of reward was just earned.
enum RewardKind { chat, task }

/// A reward event to surface in the chat UI (daily chat reward or a
/// task-completion bonus). Rendered as a celebratory bubble, then cleared.
class _RewardEvent {
  final RewardKind kind;
  final int streak;
  final int reward;
  final String? label;

  const _RewardEvent({
    required this.kind,
    required this.streak,
    required this.reward,
    this.label,
  });
}
