part of 'home_screen.dart';

/// Custom tab pills for the home screen. The accent pill tracks the tab
/// controller's animation continuously (so it glides with a swipe and eases
/// between taps), and the label colour/weight animate smoothly instead of
/// jumping between states.
class _SmoothTabPills extends StatelessWidget implements PreferredSizeWidget {
  final List<String> labels;
  final Color headerColor;
  final ValueChanged<int>? onTap;
  /// 1 = fully expanded, 0 = fully retracted while scrolling down. Driven by
  /// the home screen's scroll controller so the app-bar's bottom slot
  /// (preferredSize) collapses together with the bar itself.
  final double collapse;

  // Pill height (52) + its bottom margin (12), scaled by [collapse].
  @override
  Size get preferredSize => Size.fromHeight(64 * collapse.clamp(0.0, 1.0));

  const _SmoothTabPills({
    required this.labels,
    required this.headerColor,
    required this.onTap,
    this.collapse = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = DefaultTabController.of(context);
    final count = labels.length;
    final double collapse = this.collapse.clamp(0.0, 1.0);
    // Monotone glass: one calm tint, no per-section hues and no glossy
    // gradient — the bar reads as a single piece of frosted glass.
    final glass = scheme.surfaceContainerHighest;
    // Smooth entrance: the pill-bar fades in and settles from a few pixels
    // above on first build, so section switches never "pop" into place.
    // While scrolling down the whole thing retracts into the header: the
    // app-bar's bottom slot (preferredSize) collapses with [collapse] while
    // the bar slides up under the clip edge and fades — one fluid motion.
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: collapse,
        child: Opacity(
          opacity: collapse,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * -8),
                child: child,
              ),
            ),
            child: Container(
              height: 52,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                // Blur FIRST inside the rounded scissor, RepaintBoundary
                // INSIDE the blur: the isolated layer inherits the rounded
                // clip, so no square corners of the blur shader leak past
                // the capsule's bottom edge.
                child: BackdropFilter(
                  filter: _kBarBlur,
                  child: RepaintBoundary(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        // Frosted glass: a white sheen melting into a
                        // translucent tinted body, a bright hairline rim and
                        // soft shadows. The flat single-fill bar from the
                        // previous pass read as a plain grey rectangle and
                        // swallowed the accent pill; the layered body lifts
                        // the capsule back off the header so the pill pops.
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.35, 1.0],
                          colors: [
                            Colors.white.withValues(alpha: 0.34),
                            glass.withValues(alpha: 0.55),
                            glass.withValues(alpha: 0.42),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.38),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.shadow.withValues(alpha: 0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                          // Faint ambient glow in the accent colour below.
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.10),
                            blurRadius: 22,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: AnimatedBuilder(
                        animation:
                            controller.animation ??
                            const AlwaysStoppedAnimation(0.0),
                        builder: (context, _) {
                          final value =
                              (controller.animation?.value ?? 0).clamp(
                                0.0,
                                count - 1.0,
                              );
                          final index = controller.index;
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final segW = constraints.maxWidth / count;
                              // Gentle gel stretch while the pill travels
                              // between segments — subtle, not a rubber band.
                              final mid =
                                  (value - value.roundToDouble()).abs();
                              final extra = segW * 0.45 * mid;
                              return Stack(
                                children: [
                                  // A single monotone pill glides between
                                  // segments: no per-section tint, no bloom.
                                  Positioned(
                                    left: value * segW - extra / 2,
                                    width: segW + extra,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      margin: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          26,
                                        ),
                                        color: scheme.primary,
                                        boxShadow: [
                                          BoxShadow(
                                            color: scheme.primary.withValues(
                                              alpha: 0.20,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      for (var i = 0; i < count; i++)
                                        Expanded(
                                          child: _TabSegment(
                                            label: labels[i],
                                            selected: i == index,
                                            scheme: scheme,
                                            // Animate from inside the
                                            // controller scope: calling
                                            // DefaultTabController.of() from
                                            // the home screen's own context
                                            // (above the controller) would
                                            // silently hit the fallback and
                                            // never switch tabs.
                                            onTap: () => controller.animateTo(
                                              i,
                                              duration: const Duration(
                                                milliseconds: 520,
                                              ),
                                              curve: Curves.easeInOutCubic,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
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
}

class _TabSegment extends StatefulWidget {
  final String label;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _TabSegment({
    required this.label,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  @override
  State<_TabSegment> createState() => _TabSegmentState();
}

class _TabSegmentState extends State<_TabSegment> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onHighlightChanged: (v) {
          if (mounted && v != _pressed) setState(() => _pressed = v);
        },
        borderRadius: BorderRadius.circular(26),
        // The raw highlight is muted out; the AnimatedContainer glow below
        // is the smooth replacement.
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        child: AnimatedScale(
          scale: _pressed ? 0.945 : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: scheme.onPrimary.withValues(alpha: _pressed ? 0.16 : 0.0),
            ),
            child: Center(
              child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                // Unselected labels are deliberately translucent so the
                // capsule stays calm; the selected label keeps full contrast.
                color: widget.selected
                    ? scheme.onPrimary
                    : scheme.onSurfaceVariant.withValues(alpha: 0.62),
                fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
              child: Text(widget.label),
            ),
          ),
        ), // AnimatedContainer
      ), // AnimatedScale
    ), // InkWell
    ); // Material
  }
}

class _CategoryChips extends StatelessWidget {
  final EntryCategory current;
  final int sortMode;
  final ValueChanged<EntryCategory> onChanged;
  final VoidCallback onSort;

  const _CategoryChips({
    required this.current,
    required this.sortMode,
    required this.onChanged,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cats = const [
      EntryCategory.none,
      EntryCategory.good,
      EntryCategory.bad,
      EntryCategory.random,
    ];
    // ONE pill-bar: categories + sort share a single compact capsule. A
    // sliding highlight (Stack + AnimatedAlign) glides smoothly between
    // segments instead of per-segment fades — denser and more fluid.
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      // Blur first (inside the rounded clip), layer isolation second — the
      // blur never leaks square corners past the capsule's rounded edge.
      child: BackdropFilter(
        filter: _kBarBlur,
        child: RepaintBoundary(
        child: Container(
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
            ),
            // Layered glass: white sheen up top, tinted body below — the
            // same premium capsule treatment as the section bar above.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.3, 1.0],
              colors: [
                Colors.white.withValues(alpha: 0.20),
                scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                scheme.surfaceContainerHighest.withValues(alpha: 0.36),
              ],
            ),
          ),
          child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final idx = cats.indexOf(current);
                final segW = constraints.maxWidth / cats.length;
                return Stack(
                  children: [
                    // Sliding highlight: an AnimatedPositioned fill that
                    // always travels the SHORTEST path between segments —
                    // no alignment-fraction math to get wrong, so it can
                    // never fly off in the wrong direction.
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                      left: (idx < 0 ? 0 : idx) * segW,
                      top: 0,
                      bottom: 0,
                      width: segW,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: idx < 0 ? 0.0 : 1.0,
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                scheme.primary.withValues(alpha: 0.88),
                                scheme.primary,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.32),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final c in cats)
                          Expanded(
                            child: _ChipSegment(
                              label: L.tr(
                                context,
                                c == EntryCategory.none ? 'catAll' : c.labelKey,
                              ),
                              selected: c == current,
                              scheme: scheme,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onChanged(c);
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          // Thin divider then the sort control — still part of the same
          // pill-bar, no separate background.
          // Soft gradient hairline instead of the old flat grey strip —
          // the separator melts into the glass bar instead of reading as
          // cheap tape across the pill.
          Container(
            width: 1.5,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.outlineVariant.withValues(alpha: 0.0),
                  scheme.outlineVariant.withValues(alpha: 0.6),
                  scheme.outlineVariant.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          PressScale(
            scale: 0.88,
            child: IconButton(
              icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) =>
                  RotationTransition(
                    turns: Tween(begin: 0.75, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      ),
                      child: child,
                    ),
                  ),
              child: Icon(
                key: ValueKey(sortMode),
                sortMode == -1
                    ? Icons.drag_handle_rounded
                    : sortMode == 0
                    ? Icons.sort_rounded
                    : sortMode == 1
                    ? Icons.arrow_upward_rounded
                    : Icons.sort_by_alpha_rounded,
              ),
            ),
            onPressed: onSort,
            style: IconButton.styleFrom(
              minimumSize: const Size(34, 30),
              maximumSize: const Size(38, 30),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            ),
          ),
        ],
      ),
    ),
  ),
  ),
    );
  }
}

/// One segment of the category capsule. Kept as a stateful widget so a held
/// finger dimples just that segment (and the sort icon beside it) with the
/// same spring-back feel as the rest of the app.
class _ChipSegment extends StatefulWidget {
  final String label;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _ChipSegment({
    required this.label,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  @override
  State<_ChipSegment> createState() => _ChipSegmentState();
}

class _ChipSegmentState extends State<_ChipSegment> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) {
        if (mounted) setState(() => _pressed = true);
      },
      onTapUp: (_) {
        if (mounted) setState(() => _pressed = false);
      },
      onTapCancel: () {
        if (mounted) setState(() => _pressed = false);
      },
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight:
                    widget.selected ? FontWeight.w700 : FontWeight.w500,
                color: widget.selected
                    ? widget.scheme.onPrimary
                    : widget.scheme.onSurfaceVariant.withValues(alpha: 0.62),
                letterSpacing: 0.2,
              ),
              child: Text(
                widget.label,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
