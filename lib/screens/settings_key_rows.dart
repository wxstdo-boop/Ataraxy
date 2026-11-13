part of 'settings_screen.dart';

class _KeyPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool gradient;
  final bool large;

  const _KeyPill({
    required this.label,
    required this.onTap,
    this.gradient = false,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PressScale(
      scale: 0.94,
      haptic: true,
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(large ? 18 : 14),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: large ? 18 : 10,
            vertical: large ? 10 : 5,
          ),
          decoration: BoxDecoration(
            gradient: gradient
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primary, scheme.tertiary],
                  )
                : null,
            color: gradient ? null : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(large ? 18 : 14),
            // Prominent shadow so the main pill pops.
            boxShadow: large
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: gradient ? Colors.white : scheme.onSurfaceVariant,
              fontSize: large ? 14 : 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: large ? 0.8 : 0.5,
            ),
          ),
        ),
      ),
    ),
    );
  }
}

/// One saved API key in the «Мои ключи» sheet: tap selects it, holding it
/// for 10 full seconds deletes it (a progress ring counts the hold — the
/// long delay makes accidental deletes impossible).
class _SavedKeyRow extends StatefulWidget {
  final String keyValue;
  final bool active;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  const _SavedKeyRow({
    required this.keyValue,
    required this.active,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  State<_SavedKeyRow> createState() => _SavedKeyRowState();
}

class _SavedKeyRowState extends State<_SavedKeyRow>
    with SingleTickerProviderStateMixin {
  Timer? _hold;
  bool _holding = false;
  // Drives the trash-ring while holding (0→1 over the 10 s hold) and the
  // fade+scale-out when the key is actually deleted.
  late final AnimationController _progress;
  late final AnimationController _fadeOut;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _fadeOut = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  void _startHold() {
    _hold?.cancel();
    setState(() => _holding = true);
    _progress.forward(from: 0);
    _hold = Timer(const Duration(seconds: 10), () {
      _hold = null;
      _delete();
    });
  }

  void _cancelHold() {
    _hold?.cancel();
    _hold = null;
    _progress.stop();
    _progress.value = 0;
    if (mounted && _holding) setState(() => _holding = false);
  }

  /// Smooth removal: the row fades and shrinks away, THEN the list drops it.
  Future<void> _delete() async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _holding = false);
    await _fadeOut.forward();
    if (mounted) widget.onDelete();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _progress.dispose();
    _fadeOut.dispose();
    super.dispose();
  }

  String get _masked {
    final k = widget.keyValue;
    if (k.length <= 10) return k;
    return '${k.substring(0, 6)}…${k.substring(k.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onSelect,
      onLongPressStart: (_) => _startHold(),
      onLongPressEnd: (_) => _cancelHold(),
      onLongPressCancel: _cancelHold,
      child: FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.0).animate(_fadeOut),
        child: SizeTransition(
          // Collapse the row's height as it fades so the keys below glide
          // up smoothly — without this the row vanished and the rest of the
          // sheet jumped abruptly.
          sizeFactor: Tween(begin: 1.0, end: 0.0).animate(_fadeOut),
          alignment: Alignment.topCenter,
          child: ScaleTransition(
            scale: Tween(begin: 1.0, end: 0.94).animate(_fadeOut),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.active ? scheme.primary : Colors.transparent,
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.key_rounded,
                  size: 16,
                  color:
                      widget.active ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _masked,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                // NO always-visible trash icon — it invited accidental
                // deletes. The ring-trash only appears WHILE holding (10 s),
                // fading/scaling in smoothly.
                if (widget.active)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 17,
                    color: scheme.primary,
                  )
                else
                  AnimatedOpacity(
                    opacity: _holding ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: AnimatedScale(
                      scale: _holding ? 1 : 0.6,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      // The trash icon gets progressively outlined by a
                      // ring while the 10 s hold runs (no spinner).
                      child: AnimatedBuilder(
                        animation: _progress,
                        builder: (context, _) {
                          final p = _progress.value;
                          final color = Color.lerp(
                            scheme.onSurfaceVariant,
                            scheme.error,
                            p,
                          )!;
                          return SizedBox(
                            width: 20,
                            height: 20,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(20, 20),
                                  painter: _HoldRingPainter(p, scheme.error),
                                ),
                                Icon(
                                  Icons.delete_rounded,
                                  size: 13,
                                  color: color,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

/// Draws the ring that "outlines" the trash icon over the 10 s hold.
