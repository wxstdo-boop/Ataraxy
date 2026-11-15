part of 'home_screen.dart';

class _EntryCardPosition {
  final Offset offset;
  final int revision;
  final int filterRevision;
  final int index;

  const _EntryCardPosition(
    this.offset,
    this.revision,
    this.filterRevision,
    this.index,
  );
}

void _shiftEntryCardPositions(
  Map<String, _EntryCardPosition> positions,
  double scrollDelta, {
  required String keyPrefix,
}) {
  if (scrollDelta == 0) return;
  for (final key in positions.keys.toList()) {
    if (!key.startsWith(keyPrefix)) continue;
    final position = positions[key]!;
    positions[key] = _EntryCardPosition(
      position.offset.translate(0, -scrollDelta),
      position.revision,
      position.filterRevision,
      position.index,
    );
  }
}

class _EntryCard extends StatefulWidget {
  final int index;
  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback onPin;

  /// Hero tag for the shared-element transition into the detail screen.
  final String heroTag;

  /// Whether this card should play the fade+slide entrance. True only for the
  /// first list of the session (so the initial cascade plays once); later cards
  /// render statically. Filter transitions move cards from their prior
  /// positions when possible.
  final bool animate;
  final int movementRevision;
  final int filterRevision;
  final Map<String, _EntryCardPosition> movementPositions;

  const _EntryCard({
    super.key,
    required this.index,
    required this.entry,
    required this.onTap,
    required this.onPin,
    required this.heroTag,
    this.animate = true,
    this.movementRevision = 0,
    this.filterRevision = 0,
    required this.movementPositions,
  });

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> with TickerProviderStateMixin {
  AnimationController? _ctrl;
  Animation<double>? _opacity;
  Animation<Offset>? _slide;
  AnimationController? _movementCtrl;
  Animation<Offset>? _movement;
  AnimationController? _filterCtrl;
  Animation<double>? _filterOpacity;
  Offset? _movementOrigin;

  @override
  void initState() {
    super.initState();
    final previous = widget.movementPositions[widget.heroTag];
    if (previous != null &&
        previous.revision != widget.movementRevision &&
        previous.filterRevision == widget.filterRevision) {
      _movementOrigin = previous.offset;
    }
    if (previous != null &&
        previous.filterRevision != widget.filterRevision &&
        previous.index != widget.index) {
      _movementOrigin = previous.offset;
    } else if (!widget.animate &&
        widget.filterRevision > 0 &&
        (previous == null ||
            previous.filterRevision != widget.filterRevision)) {
      _playFilterTransition();
    }
    _schedulePositionUpdate();
    // First list of the session: `animate` staggers the initial cascade.
    if (widget.animate) _play();
  }

  @override
  void didUpdateWidget(covariant _EntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep surviving cards visible; animate only the ones whose list position
    // changed rather than fading or translating the entire feed.
    if (oldWidget.movementRevision != widget.movementRevision &&
        oldWidget.index != widget.index) {
      _movementOrigin = oldWidget.movementPositions[oldWidget.heroTag]?.offset;
    }
    if (oldWidget.filterRevision != widget.filterRevision &&
        oldWidget.index != widget.index) {
      _movementOrigin = oldWidget.movementPositions[oldWidget.heroTag]?.offset;
    }
    _schedulePositionUpdate();
  }

  Offset? _currentPosition() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero);
  }

  void _playFilterTransition() {
    _filterCtrl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _filterOpacity ??= Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _filterCtrl!, curve: Curves.easeOutCubic),
    );
    _filterCtrl!.forward(from: 0);
  }

  void _schedulePositionUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = _currentPosition();
      if (current == null) return;
      final origin = _movementOrigin;
      _movementOrigin = null;
      widget.movementPositions[widget.heroTag] = _EntryCardPosition(
        current,
        widget.movementRevision,
        widget.filterRevision,
        widget.index,
      );
      if (origin == null) return;
      final delta = Offset(0, origin.dy - current.dy);
      if (delta.dy.abs() < 1 ||
          delta.dy.abs() > MediaQuery.sizeOf(context).height) {
        return;
      }
      _movementCtrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 320),
      );
      _movementCtrl!.stop();
      _movement = Tween<Offset>(begin: delta, end: Offset.zero).animate(
        CurvedAnimation(parent: _movementCtrl!, curve: Curves.easeInOutCubic),
      );
      setState(() {});
      _movementCtrl!.forward(from: 0);
    });
  }

  /// (Re)starts the fade+slide. Creates the controller lazily so cards that
  /// never animate keep no controller and no timers (scroll/rebuild jank).
  void _play() {
    _ctrl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacity ??= CurvedAnimation(parent: _ctrl!, curve: Curves.easeOut);
    _slide ??= Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl!, curve: Curves.easeOutCubic));
    _ctrl!.value = 0;
    // Subtle cascade: barely-there stagger so a batch of new cards (search
    // results, category switch) reads as one soft wave, not a slow parade.
    final delay = Duration(milliseconds: 8 + widget.index.clamp(0, 6) * 18);
    Future.delayed(delay, () {
      if (mounted) _ctrl?.forward();
    });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _movementCtrl?.dispose();
    _filterCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildCard(context);
  }

  Widget _buildCard(BuildContext context) {
    // NOTE: whether the card animates is decided ONCE, in initState — it must
    // NOT be re-read from `widget.animate` here. The parent computes
    // `animate` via `seenEntranceIds.add(id)`, which is false on every build
    // AFTER the first. A rebuild mid-animation (e.g. the feed reload that
    // lands right after the greeting) used to see `animate == false` and swap
    // the FadeTransition out for the bare body — the in-flight fade was
    // dropped and the card POPPED to full opacity. That snap, on top of the
    // entrance that had just started, is the "дёргает записи по двойному".
    final ctrl = _ctrl;
    Widget card;
    if (ctrl == null) {
      card = _EntryCardBody(
        entry: widget.entry,
        index: widget.index,
        heroTag: widget.heroTag,
        onTap: widget.onTap,
        onPin: widget.onPin,
      );
    } else {
      card = FadeTransition(
        opacity: _opacity!,
        child: SlideTransition(
          position: _slide!,
          child: _EntryCardBody(
            entry: widget.entry,
            index: widget.index,
            heroTag: widget.heroTag,
            onTap: widget.onTap,
            onPin: widget.onPin,
          ),
        ),
      );
    }
    final filterCtrl = _filterCtrl;
    final filterOpacity = _filterOpacity;
    if (filterCtrl != null && filterOpacity != null) {
      card = FadeTransition(opacity: filterOpacity, child: card);
    }
    final movement = _movement;
    final movementCtrl = _movementCtrl;
    if (movement == null || movementCtrl == null) return card;
    return AnimatedBuilder(
      animation: movementCtrl,
      child: card,
      builder: (context, child) =>
          Transform.translate(offset: movement.value, child: child),
    );
  }
}

class _EntryCardBody extends StatefulWidget {
  final int index;
  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback onPin;

  /// Hero tag for the shared-element transition into the detail screen.
  final String heroTag;

  const _EntryCardBody({
    required this.index,
    required this.entry,
    required this.onTap,
    required this.onPin,
    required this.heroTag,
  });

  @override
  State<_EntryCardBody> createState() => _EntryCardBodyState();
}

class _EntryCardBodyState extends State<_EntryCardBody> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Smooth animated outline that fades in while the card is pressed and
    // fades out on release (no abrupt jump in either direction).
    // Wrap with RepaintBoundary to prevent card repaints from affecting other cards
    return RepaintBoundary(
      // A held card dips in slightly (and springs back) so a press is felt,
      // not just seen via the brightening surface.
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _pressed
                  ? scheme.primary.withValues(alpha: 0.45)
                  : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            // No elevation: a blurred shadow on every card is the #1 FPS killer
            // in a scrolling list on low-end GPUs (Redmi). The border + gradient
            // carry the depth instead — zero shadow cost.
            elevation: 0,
            color: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onTap();
              },
              onLongPress: widget.onPin,
              onHighlightChanged: (v) {
                if (mounted && v != _pressed) {
                  setState(() => _pressed = v);
                }
              },
              borderRadius: BorderRadius.circular(24),
              // The raw grey splash/highlight is muted out; the animated border
              // + surface brighten (both 260ms) are the smooth replacement.
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              // Frosted-glass card: a single translucent surface layer so the
              // ambient wash behind the feed shows through. One layer (not a
              // two-stop gradient) — cheaper to composite on low-end GPUs.
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  // Press highlight: the surface brightens softly (same 260ms
                  // ease-out as the border) instead of the raw grey InkWell
                  // block flashing in.
                  //
                  // surfaceContainerHighest, NOT Low: Low is near-neutral white on
                  // the light themes while the scaffold keeps the theme tint, so a
                  // column of cards read as WHITE STRIPES over the coloured feed.
                  // Highest carries the tint and still separates from the wash.
                  color: scheme.surfaceContainerHighest.withValues(
                    alpha: _pressed ? 0.98 : 0.85,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: _TypeBadge(type: widget.entry.type)),
                          if (widget.entry.type == EntryType.dream &&
                              widget.entry.isLucid != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.entry.isLucid!
                                      ? scheme.tertiaryContainer
                                      : scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  widget.entry.isLucid!
                                      ? L.tr(context, 'dreamLucid')
                                      : L.tr(context, 'dreamNormal'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    // Theme containers instead of hardcoded amber:
                                    // a saturated yellow chip on a pastel palette
                                    // was the harshest element on the card.
                                    color: widget.entry.isLucid!
                                        ? scheme.onTertiaryContainer
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Pin badge: fades + scales in/out in place instead of
                          // popping when the entry is pinned/unpinned. The slot is
                          // always reserved (fixed-width SizedBox) so the date to
                          // its right never shifts sideways mid-animation.
                          SizedBox(
                            width: 20,
                            child: AnimatedScale(
                              scale: widget.entry.pinned ? 1.0 : 0.4,
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutBack,
                              child: AnimatedOpacity(
                                opacity: widget.entry.pinned ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                child: Icon(
                                  Icons.push_pin_rounded,
                                  size: 16,
                                  // Semi-transparent red pin (was theme primary /
                                  // hardcoded orange) — reads as a quiet "pinned"
                                  // marker in every theme.
                                  color: AppAccents.danger.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (widget.entry.category != EntryCategory.none) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _categoryColor(
                                  widget.entry.category,
                                ).withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                L.tr(context, widget.entry.category.labelKey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _categoryColor(widget.entry.category),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              widget.entry.formattedDate,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Hero(
                        tag: 'entry-title-${widget.heroTag}',
                        child: Material(
                          type: MaterialType.transparency,
                          child: Text(
                            widget.entry.title.isEmpty
                                ? L.tr(context, 'withoutTitle')
                                : widget.entry.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _MarkdownPreview(
                        text: widget.entry.content,
                        scheme: scheme,
                      ),
                      if (widget.entry.tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.entry.tags
                              .map(
                                (t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '#$t',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      // Mood indicator — small filled stars matching the entry mood.
                      if (widget.entry.mood > 0) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: List.generate(5, (i) {
                            final on = i < widget.entry.mood;
                            return Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: Icon(
                                on
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 16,
                                // Semi-transparent red mood stars (were theme
                                // primary / hardcoded amber).
                                color: on
                                    ? AppAccents.danger.withValues(alpha: 0.7)
                                    : AppAccents.danger.withValues(alpha: 0.22),
                              ),
                            );
                          }),
                        ),
                      ],
                    ],
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

Color _categoryColor(EntryCategory c) {
  // Muted accents from the shared palette: the stock green / redAccent /
  // blueAccent dots were the most saturated pixels on every entry card.
  return switch (c) {
    EntryCategory.good => AppAccents.sage,
    EntryCategory.bad => AppAccents.danger,
    EntryCategory.random => AppAccents.sky,
    EntryCategory.none => AppAccents.slate,
  };
}

class _TypeBadge extends StatelessWidget {
  final EntryType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Theme-driven two-stop gradient per entry type + a matching icon — the
    // badge always belongs to the active palette instead of hardcoded hues.
    final (List<Color> colors, IconData icon) = switch (type) {
      EntryType.dream => (
        [scheme.primary, scheme.tertiary],
        Icons.nights_stay_rounded,
      ),
      EntryType.life => (
        [scheme.secondary, scheme.primary],
        Icons.self_improvement_rounded,
      ),
      EntryType.general => (
        [scheme.primary, scheme.primaryContainer],
        Icons.edit_note_rounded,
      ),
      EntryType.tulpa => (
        [scheme.tertiary, scheme.secondary],
        Icons.psychology_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            L.tr(context, type.labelKey),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders markdown inside an entry card preview with the same look used in
/// the full detail view, but non-selectable and tightly padded.
/// Always uses MarkdownBody so plain text, English markdown and
/// Cyrillic markdown all render correctly (no **** fallback).
class _MarkdownPreview extends StatelessWidget {
  final String text;
  final ColorScheme scheme;
  const _MarkdownPreview({required this.text, required this.scheme});

  /// True when [s] contains any markdown syntax token. The common case on
  /// Redmi (and everywhere else) is a plain-text note — running the whole
  /// markdown parser + layout on EVERY visible card on EVERY rebuild was
  /// the main scroll jank. A cheap pre-scan lets plain text skip the parser
  /// entirely and use a simple Text instead.
  static bool _hasMarkdown(String s) {
    // Fast scans: no loop unless one of these chars appears at all.
    if (!s.contains('*') &&
        !s.contains('#') &&
        !s.contains('_') &&
        !s.contains('`') &&
        !s.contains('>') &&
        !s.contains('[') &&
        !s.contains(']') &&
        !s.contains('-') &&
        !s.contains('~')) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Em-dash on display: punctuation hyphens render as long dashes in the
    // feed just like in the editor and the reading view.
    final display = emDash(text);
    if (display.isEmpty) {
      return Text(
        '—',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.55),
        ),
      );
    }
    // Fast path: plain text (no markdown tokens) → cheap Text, no parser.
    // This is the dominant case for notes; it keeps scrolling smooth on
    // low-end devices. The parser path below is only for real markdown.
    if (!_hasMarkdown(text)) {
      return Text(
        display,
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.78),
          height: 1.4,
        ),
      );
    }
    // Cap what the parser sees: the preview shows ~6 lines and the card
    // clips at 220px, so feeding an 800k-char entry to MarkdownBody on
    // EVERY rebuild (scroll, theme, tab) made lists crawl on low-end GPUs.
    // Truncating to a few KB keeps the parse near-instant — the preview
    // never shows more than that anyway.
    final previewText = display.length > 4000
        ? display.substring(0, 4000)
        : display;
    return RepaintBoundary(
      child: ClipRect(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: MarkdownBody(
            data: previewText,
            shrinkWrap: true,
            selectable: false,
            // Keep the user's own line breaks: a single \n in the editor
            // renders as a real line break, not a collapsed space.
            softLineBreak: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              // A blank-line paragraph break must read as MORE than a line
              // break — the gap is derived from the line leading (the library
              // default and a flat constant both read as merged).
              blockSpacing: markdownBlockSpacing(
                theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              p: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.78),
                height: 1.4,
              ),
              h1: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
              h2: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
              h3: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
              strong: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
              em: const TextStyle(fontStyle: FontStyle.italic),
              del: TextStyle(
                decoration: TextDecoration.lineThrough,
                color: scheme.onSurfaceVariant,
              ),
              code: TextStyle(
                backgroundColor: scheme.surfaceContainerHighest,
                fontFamily: 'monospace',
                fontSize: 12,
                color: scheme.onSurface,
              ),
              blockquoteDecoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: scheme.primary, width: 3),
                ),
              ),
              blockquotePadding: const EdgeInsets.only(left: 8),
              listBullet: TextStyle(color: scheme.primary),
              listIndent: 12,
              a: TextStyle(
                color: scheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
