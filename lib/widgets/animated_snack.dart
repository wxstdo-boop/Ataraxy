import 'dart:async';

import 'package:flutter/material.dart';

import 'package:ataraxy/theme/app_theme.dart';

/// Типы снекбаров — влияют на иконку и акцент.
/// Цвет фона/текста всегда берётся из snackBarTheme текущей темы.
enum SnackType { info, success, error, warning }

/// Единый, плавный снекбар на Overlay.
///
/// В отличие от штатного [SnackBar] (который быстро выезжает и мгновенно
/// исчезает без заметной анимации закрытия), этот рисует снекбар сам через
/// [OverlayEntry] с AnimationController: появление = fade + slide-up,
/// закрытие = fade + slide-down. Один и тот же вид у всех уведомлений —
/// иконка в цветной плитке + текст, цвета из темы (светлые на светлых
/// темах, тёмные на тёмных).
///
/// Когда показывается новый снекбар, пока старый ещё на экране, старый
/// ПЛАВНО уезжает (анимированное закрытие), и только потом въезжает новый —
/// без резких скачков при быстрых последовательных уведомлениях.
class AnimatedSnack {
  static OverlayEntry? _current;
  static _AnimatedSnackHostState? _currentState;
  // Dedupe: the same message within the window below is dropped instead of
  // queued. Hammering "Разблокировать" with a wrong dev password used to
  // stack a pile of identical "Неверный пароль" bars, each queued for 3s.
  static String? _lastMessage;
  static DateTime _lastShownAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _dedupeWindow = Duration(milliseconds: 2500);

  static void show(
    BuildContext context,
    String message, {
    SnackType type = SnackType.info,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final now = DateTime.now();
    if (message == _lastMessage &&
        now.difference(_lastShownAt) < _dedupeWindow) {
      return;
    }
    _lastMessage = message;
    _lastShownAt = now;
    final overlay = Overlay.of(context, rootOverlay: true);
    _showAfter(overlay, message, type, duration, action);
  }

  static Future<void> _showAfter(
    OverlayState overlay,
    String message,
    SnackType type,
    Duration duration,
    SnackBarAction? action,
  ) async {
    // Detach the current bar, then animate it out — the NEW bar is queued
    // only after the old one has fully slid away, so rapid-fire messages
    // (e.g. PIN removed) never look like they're jumping between screens.
    final prevState = _currentState;
    _currentState = null;
    if (prevState != null) {
      await prevState.animateOut();
    }
    if (!overlay.mounted) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _AnimatedSnackHost(
        message: message,
        type: type,
        duration: duration,
        action: action,
        onDone: () {
          debugPrint('[SNACK-ENTRY] onDone remove: ${entry.hashCode}');
          if (_current == entry) _current = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    debugPrint('[SNACK-ENTRY] inserted: ${entry.hashCode}');
    _current = entry;
    overlay.insert(entry);
  }

  /// Called by [_AnimatedSnackHostState.initState] so the manager can
  /// animate the CURRENT bar out before the next one slides in.
  static void _register(_AnimatedSnackHostState state) {
    if (_current != null && _currentState == null) {
      _currentState = state;
    }
  }

  /// Immediately removes the current snackbar (used before navigation).
  static void dismiss() {
    _currentState?.animateOut(immediate: true);
    _current?.remove();
    _current = null;
    _currentState = null;
  }
}

class _AnimatedSnackHost extends StatefulWidget {
  final String message;
  final SnackType type;
  final Duration duration;
  final SnackBarAction? action;
  final VoidCallback onDone;

  const _AnimatedSnackHost({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDone,
    this.action,
  });

  @override
  State<_AnimatedSnackHost> createState() => _AnimatedSnackHostState();
}

class _AnimatedSnackHostState extends State<_AnimatedSnackHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _holdTimer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    // Register this host so the manager can animate it out before showing
    // the next snackbar (instead of hard-removing → jumping).
    AnimatedSnack._register(this);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Enter: animate in, then hold, then animate out.
    _ctrl.forward().then((_) {
      if (!mounted) return;
      _holdTimer = Timer(widget.duration, _close);
    });
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _holdTimer?.cancel();
    await _ctrl.reverse();
    if (mounted) widget.onDone();
  }

  /// Animates this snackbar out. [immediate] skips the animation for
  /// navigation teardown.
  Future<void> animateOut({bool immediate = false}) async {
    if (!mounted) return;
    if (immediate) {
      _closing = true;
      _holdTimer?.cancel();
      if (mounted) widget.onDone();
      return;
    }
    await _close();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snackTheme = theme.snackBarTheme;
    final scheme = theme.colorScheme;
    final bg = snackTheme.backgroundColor ?? scheme.inverseSurface;
    final fg = snackTheme.contentTextStyle?.color ?? scheme.onInverseSurface;

    final (icon, accent) = switch (widget.type) {
      // Muted semantic accents (see [AppAccents]) — the stock green /
      // redAccent / orange icons were the loudest thing in every snackbar.
      SnackType.success => (Icons.check_circle_rounded, AppAccents.sage),
      SnackType.error => (Icons.error_rounded, AppAccents.danger),
      SnackType.warning => (Icons.warning_amber_rounded, AppAccents.amber),
      // Info gets its own icon too, so ALL notifications share the same
      // layout (icon tile + text) — previously info bars had no icon and
      // looked different from success/error ones.
      SnackType.info => (Icons.info_rounded, scheme.primary),
    };

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16 + MediaQuery.of(context).padding.bottom,
      child: SafeArea(
        top: false,
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _opacity,
            child: Material(
              elevation: 8,
              color: bg,
              shadowColor: scheme.shadow.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // Icon tile: tinted rounded square in the accent
                      // colour, same for every snack type.
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(icon, color: accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: (snackTheme.contentTextStyle ??
                                  const TextStyle())
                              .copyWith(
                            color: fg,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            height: 1.25,
                          ),
                        ),
                      ),
                      if (widget.action != null) ...[
                        const SizedBox(width: 10),
                        // Rounded pill action button, tinted with the
                        // snack accent so it reads as a call-to-action.
                        Material(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              widget.action!.onPressed();
                              _close();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Text(
                                widget.action!.label,
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    );
  }
}
