part of 'home_screen.dart';

class _EntryCard extends StatefulWidget {
  final int index;
  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback onPin;

  /// Hero tag for the shared-element transition into the detail screen.
  final String heroTag;

  /// Whether this card should play the fade+slide entrance. False after the
  /// first list of the session has animated — later cards render statically
  /// (no controller, no timers), which removes scroll/rebuild jank.
  final bool animate;

  const _EntryCard({
    super.key,
    required this.index,
    required this.entry,
    required this.onTap,
    required this.onPin,
    required this.heroTag,
    this.animate = true,
  });

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  Animation<double>? _opacity;
  Animation<Offset>? _slide;

  @override
  void initState() {
    super.initState();
    if (!widget.animate) return;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacity = CurvedAnimation(parent: _ctrl!, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl!, curve: Curves.easeOutCubic));

    // Stagger: каждая карточка запускается чуть позже предыдущей, but the
    // whole sequence finishes well within the splash's fully-opaque hold
    // (~770 ms), so the cards are already settled when the splash fades —
    // no "flash" of the home screen after the transition.
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: whether the card animates is decided ONCE, in initState — it must
    // NOT be re-read from `widget.animate` here. The parent computes
    // `animate` via `seenEntranceIds.add(id)`, which is false on every build
    // AFTER the first. A rebuild mid-animation (e.g. the feed reload that
    // lands right after the greeting) used to see `animate == false` and swap
    // the FadeTransition out for the bare body — the in-flight fade was
    // dropped and the card POPPED to full opacity. That snap, on top of the
    // entrance that had just started, is the "дёргает записи по двойному".
    final ctrl = _ctrl;
    if (ctrl == null) {
      return _EntryCardBody(
        entry: widget.entry,
        index: widget.index,
        heroTag: widget.heroTag,
        onTap: widget.onTap,
        onPin: widget.onPin,
      );
    }
    return FadeTransition(
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
              color: scheme.surfaceContainerLow
                  .withValues(alpha: _pressed ? 0.98 : 0.85),
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
                              // Theme-aware pin (was hardcoded orange).
                              color: scheme.primary,
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
                                color: scheme.onSurface.withValues(alpha: 0.5),
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
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _MarkdownPreview(text: widget.entry.content, scheme: scheme),
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
                                color: scheme.primary.withValues(alpha: 0.1),
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
                            // Theme-aware mood stars (were hardcoded amber).
                            color: on ? scheme.primary : scheme.outlineVariant,
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
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.32),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
    final previewText =
        display.length > 4000 ? display.substring(0, 4000) : display;
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
