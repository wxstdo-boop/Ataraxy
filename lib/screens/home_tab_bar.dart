part of 'home_screen.dart';

/// Custom tab pills for the home screen. The white pill tracks the tab
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
    // The capsule's own body colour, built the way the glass is painted
    // (header under primaryContainer under the white sheen). The spots have to
    // contrast with THIS, not with the palette — see [_spotColor].
    final glass = Color.lerp(
      Color.lerp(headerColor, scheme.primaryContainer, 0.55)!,
      Colors.white,
      0.15,
    )!;
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
        // Blur FIRST inside the rounded scissor, RepaintBoundary INSIDE the
        // blur: the isolated layer inherits the rounded clip, so no square
        // corners of the blur shader leak past the capsule's bottom edge.
        child: BackdropFilter(
          filter: _kBarBlur,
          child: RepaintBoundary(
            child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              // Premium-glass border: thick, bright hairline that catches
              // light all the way around the capsule (2dp reads like a
              // solid glass rim instead of a cheap 1px outline).
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.42),
                width: 2,
              ),
              // Layered body: strong white sheen up top melting into the
              // tinted glass, with soft shadows that lift the capsule off
              // the header — the depth premium UI needs.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.30, 1.0],
                colors: [
                  Colors.white.withValues(alpha: 0.30),
                  scheme.primaryContainer.withValues(alpha: 0.56),
                  scheme.primaryContainer.withValues(alpha: 0.34),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                // Faint ambient glow in the accent color under the bar.
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Glossy catch-light: a soft white band sweeping across the
                // upper edge of the capsule — the detail that separates
                // premium glass from a flat translucent rectangle.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 24,
                  child: IgnorePointer(
                    ignoring: true,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.9],
                          colors: [
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
              animation: controller.animation ?? const AlwaysStoppedAnimation(0.0),
        builder: (context, _) {
          final value = (controller.animation?.value ?? 0).clamp(
            0.0,
            count - 1.0,
          );
          final index = controller.index;
          return LayoutBuilder(
            builder: (context, constraints) {
              final segW = constraints.maxWidth / count;
              // "Snake" gel stretch: while the pill travels between segments
              // it elongates (up to ~40% wider at the midpoint of the flight)
              // and settles back to its resting width on arrival — the pill
              // reads as a stretchy gel snake instead of a rigid block jump.
              final mid = (value - value.roundToDouble()).abs();
              final extra = segW * 0.8 * mid;
              return Stack(
                children: [
                  // Theme-tinted spots behind EVERY segment: each section keeps
                  // its own hue pulled from the active palette. `focus` is
                  // derived from the tab controller's continuous value, so the
                  // idle spots dim as the pill leaves and the neighbour's
                  // brightens, cross-fading instead of snapping on arrival.
                  for (var i = 0; i < count; i++)
                    Positioned(
                      left: i * segW,
                      width: segW,
                      top: 0,
                      bottom: 0,
                      child: _TabBlob(
                        color: _spotColor(glass, _sectionTint(scheme, i)),
                        focus: (1 - (value - i).abs()).clamp(0.0, 1.0),
                      ),
                    ),
                  // The bloom rides UNDER the pill and follows it continuously
                  // (same x/width math as the pill below, minus the stretch),
                  // so it reads as light leaking out from behind the tab
                  // rather than a fixed spotlight on one segment.
                  Positioned(
                    left: value * segW - segW * 0.25,
                    width: segW * 1.5,
                    top: 0,
                    bottom: 0,
                    child: _TabBlob(
                      color: _spotColor(
                        glass,
                        _sectionTint(
                          scheme,
                          value.round().clamp(0, count - 1),
                        ),
                      ),
                      focus: 1,
                      bloom: true,
                    ),
                  ),
                  // The pill follows the animation continuously: glides with
                  // swipes, springs between tabs on taps.
                  Positioned(
                    left: value * segW - extra / 2,
                    width: segW + extra,
                    top: 0,
                    bottom: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        // Soft top-lit gradient keeps the pill from reading
                        // as a flat color block while it glides.
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            scheme.primary.withValues(alpha: 0.9),
                            scheme.primary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
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
                            // Animate from inside the controller scope:
                            // calling DefaultTabController.of() from the
                            // home screen's own context (above the
                            // DefaultTabController) would silently hit the
                            // fallback controller and never switch tabs.
                            // Long ease-in-out glide (520ms) — the active
                            // pill "snakes" between sections instead of
                            // snapping with the default 300ms jump.
                            onTap: () => controller.animateTo(
                              i,
                              duration: const Duration(milliseconds: 520),
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
          ],
        ),
    ),
  ),
  ),
      ),
  ),
      ), // TweenAnimationBuilder (entrance)
    ), // Opacity(collapse)
  ), // Align(heightFactor)
); // ClipRect
  }
}

/// Per-section accent: the theme's primary hue fanned out by a fixed offset
/// per tab. Pulling straight from `primary/secondary/tertiary` made all four
/// spots the same violet on the lavender theme (and the same peach on the
/// peach one), so the blobs read as "nothing there"; a ±30° fan keeps every
/// spot inside the palette while making the tabs tellably different.
Color _sectionTint(ColorScheme s, int i) {
  // Distinct enough to tell four sections apart, close enough to stay inside
  // the palette: ±64° on a purple theme produced a green→magenta rainbow.
  // The fan is now ±24° with only a light saturation lift — the spots read as
  // four steps of the same hue instead of four neon lamps, which is what made
  // the tab bar feel "вырвиглазно" next to the calmed palette.
  const offsets = [-24.0, -8.0, 8.0, 24.0];
  final hsl = HSLColor.fromColor(s.primary);
  return hsl
      .withHue((hsl.hue + offsets[i % offsets.length]) % 360)
      .withSaturation((hsl.saturation * 1.10).clamp(0.0, 0.60))
      .toColor();
}

/// The spot colour for one segment, anchored to the glass it is painted on.
///
/// Deriving the spot from the palette alone was the first bug: on the dark
/// theme the capsule interior measures RGB(110,112,120) — saturation 0.01 —
/// and the Grok `primary` is equally neutral, so any palette-derived tint
/// landed within a few units of the glass. The second bug was a timid
/// distance: +0.22 lightness at 0.30 saturation composited to ~+20/255 in a
/// single channel, which the eye reads as "no spot". The values below are the
/// fix that made the spots visible, softened by one step (0.48 saturation
/// floor, ±0.24 lightness): still unmistakably readable on the near-neutral
/// dark glass, no longer the most saturated pixels on the screen.
Color _spotColor(Color glass, Color tint) {
  final g = HSLColor.fromColor(glass);
  final t = HSLColor.fromColor(tint);
  final sat = t.saturation < 0.48 ? 0.48 : t.saturation;
  return g.withHue(t.hue)
      .withSaturation(sat.clamp(0.0, 1.0))
      .withLightness(
        (g.lightness + (g.lightness < 0.55 ? 0.24 : -0.22)).clamp(0.06, 0.94),
      )
      .toColor();
}

/// A soft radial spot sitting behind one tab segment. Idle segments keep a
/// faint hint of their own color; the spot the pill rests on swells wider and
/// brighter — and because the gradient is an ellipse fitted to the segment
/// box, `radius > 1` lets it bleed past the segment edges and glow out from
/// around the pill. Pure gradient paint — no extra BlurFilter layer, so it
/// costs nothing on low-end devices (Redmi Note 12).
class _TabBlob extends StatelessWidget {
  final Color color;

  /// 0 = idle, 1 = the pill is parked on this segment.
  final double focus;

  /// The traveling glow that rides under the pill: wider box, stronger core.
  final bool bloom;

  const _TabBlob({
    required this.color,
    required this.focus,
    this.bloom = false,
  });

  @override
  Widget build(BuildContext context) {
    // [color] arrives already contrasted against the glass (see [_spotColor]).
    // The old ellipse (radius 0.72, single linear fade) left most of the
    // segment bare and averaged out to ~+20/255 — invisible. It now covers
    // the whole segment with a plateau core, so the hue reads at a glance.
    final spot = color;
    final core = spot.withValues(alpha: bloom ? 0.85 : 0.70 + 0.30 * focus);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, 0.18),
            radius: bloom ? 1.5 : 1.15 + 0.15 * focus,
            colors: [core, core, spot.withValues(alpha: 0.0)],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: const SizedBox.expand(),
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
                color: widget.selected
                    ? scheme.onPrimary
                    : scheme.onPrimaryContainer,
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
            // same premium capsule treatment as the section bar.
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
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  onChanged(c);
                                },
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: AnimatedDefaultTextStyle(
                                      duration:
                                          const Duration(milliseconds: 400),
                                      curve: Curves.easeOutCubic,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: c == current
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: c == current
                                            ? scheme.onPrimary
                                            : scheme.onSurfaceVariant.withValues(alpha: 0.85),
                                        letterSpacing: 0.2,
                                      ),
                                      child: Text(
                                        L.tr(
                                          context,
                                          c == EntryCategory.none
                                              ? 'catAll'
                                              : c.labelKey,
                                        ),
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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
          IconButton(
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
            tooltip: sortMode == -1
                ? L.tr(context, 'sortManual')
                : sortMode == 0
                ? L.tr(context, 'sortNewest')
                : sortMode == 1
                ? L.tr(context, 'sortOldest')
                : L.tr(context, 'sortAlpha'),
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
        ],
      ),
    ),
  ),
  ),
    );
  }
}
