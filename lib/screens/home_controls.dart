part of 'home_screen.dart';

class _ReminderDialog extends StatelessWidget {
  final AppSettings settings;

  const _ReminderDialog({required this.settings});

  @override
  Widget build(BuildContext context) {
    return ReminderDialog(settings: settings);
  }
}

/// Search now only acts as a compact toggle; it does not open a text field.
/// A fixed-size icon keeps the toolbar from moving between states.
///
/// The tooltip label ("Поиск" ↔ "Закрыть поиск") deliberately LAGS the icon by
/// one transition: the icon cross-fades (280ms) and the current tooltip fades
/// out (showDuration 400ms) FIRST — only then does the label swap, while the
/// tooltip is hidden. Swapping the label in lockstep with the icon made the
/// text jump mid-fade, which read as a glitch.
class _SearchToggleButton extends StatefulWidget {
  final bool isSearching;
  final VoidCallback onTap;

  const _SearchToggleButton({
    required this.isSearching,
    required this.onTap,
  });

  @override
  State<_SearchToggleButton> createState() => _SearchToggleButtonState();
}

class _SearchToggleButtonState extends State<_SearchToggleButton> {
  /// Currently shown tooltip label. Kept stable during the icon cross-fade so
  /// the tooltip text never swaps in the middle of the transition.
  String _tooltipText = '';

  int _swapToken = 0;

  String _labelFor(BuildContext context) =>
      L.tr(context, widget.isSearching ? 'closeSearch' : 'search');

  @override
  void didUpdateWidget(covariant _SearchToggleButton old) {
    super.didUpdateWidget(old);
    if (old.isSearching == widget.isSearching) return;
    final token = ++_swapToken;
    // Delay the label swap until the icon fade (280ms) has finished AND the
    // previous tooltip has faded out (400ms) — the swap then happens while
    // the tooltip is hidden, so the state change reads as ONE smooth motion.
    Future<void>.delayed(const Duration(milliseconds: 520)).then((_) {
      if (!mounted || token != _swapToken) return;
      final next = _labelFor(context);
      if (_tooltipText != next) setState(() => _tooltipText = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_tooltipText.isEmpty) _tooltipText = _labelFor(context);
    return Tooltip(
      message: _tooltipText,
      // Hold the tooltip for only a beat after a long-press release, then let
      // it fade — so a quick tap right after never catches the label swap
      // while the tooltip is still on screen.
      showDuration: const Duration(milliseconds: 400),
      child: PressableIconButton(
        onPressed: widget.onTap,
        // Clean cross-fade between the search glass and the X. The earlier
        // rotation + easeOutBack version overshot the icon scale and flashed
        // a big blurry block on low-end GPUs — a plain fade is smooth on all
        // devices. The press itself is the soft "dimple" (scale 0.86 + halo).
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Icon(
            key: ValueKey(widget.isSearching),
            widget.isSearching ? Icons.close_rounded : Icons.search_rounded,
          ),
        ),
      ),
    );
  }
}

/// Slides a floating control (the "+" FAB / reminders button) out of the
/// way when the user scrolls down and glides it back when they scroll up.
class _FadeSlideFab extends StatelessWidget {
  final bool visible;
  final Widget child;
  const _FadeSlideFab({required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      // One 300ms glide for all three layers. At 520ms the FAB was still
      // sliding after a fast flick, so it lingered over the cards it should
      // already be out of the way of.
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      offset: visible ? Offset.zero : const Offset(0, 1.6),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        scale: visible ? 1.0 : 0.8,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          opacity: visible ? 1.0 : 0.0,
          child: IgnorePointer(ignoring: !visible, child: child),
        ),
      ),
    );
  }
}

/// The circular "＋" button. A StatefulWidget so the press gives a tactile
/// *dimple* — the whole disc dips to 0.92 with a soft halo while the finger
/// is down, and springs back on release. Way smoother than the stock
/// InkWell highlight, and the haptics are only fired once per press.
class _PressFab extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _PressFab({required this.onTap, required this.onLongPress});

  @override
  State<_PressFab> createState() => _PressFabState();
}

class _PressFabState extends State<_PressFab> {
  bool _pressed = false;
  bool _wasLong = false;

  void _down() {
    _wasLong = false;
    setState(() => _pressed = true);
  }

  void _up() {
    if (!mounted) return;
    setState(() => _pressed = false);
    if (!_wasLong) widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => _down(),
      onTapUp: (_) => _up(),
      onTapCancel: () {
        _wasLong = false;
        if (mounted) setState(() => _pressed = false);
      },
      onLongPress: () {
        _wasLong = true;
        HapticFeedback.mediumImpact();
        widget.onLongPress();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Material(
          color: scheme.primary,
          elevation: _pressed ? 2 : 6,
          shadowColor: scheme.primary.withValues(alpha: 0.4),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          // Gentle light halo when pressed, transparent otherwise.
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            color: Colors.white.withValues(alpha: _pressed ? 0.16 : 0.0),
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  final List<JournalEntry> entries;
  final void Function(JournalEntry) onTap;
  final void Function(JournalEntry) onPin;
  final Future<void> Function() onRefresh;
  final void Function(int, int)? onReorder;
  final String emptyText;

  /// Optional banner(s) rendered as the list header so they scroll AWAY
  /// with the entries instead of being pinned above the list (the old
  /// Column layout kept practice/favorites banners frozen at the top,
  /// eating screen space while the feed scrolled beneath them).
  final Widget? header;

  /// Namespace for Hero tags so the same entry shown in different tabs
  /// (e.g. "Сны" and "Все") never shares a tag with itself.
  final String heroPrefix;

  const _ListSection({
    super.key,
    required this.entries,
    required this.onTap,
    required this.onPin,
    required this.onRefresh,
    this.onReorder,
    required this.emptyText,
    this.header,
    this.heroPrefix = '',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Cards animate whenever they are NEW to the list (per-entry keys make
    // this precise); see the class-level comment above the file's header.
    // NOTE: the scroll views deliberately keep a STABLE key. They used to be
    // keyed by a content signature, which remounted the list on every tab /
    // category switch — that reset the scroll offset and replayed every card's
    // entrance at once, which is what read as a "jump".
    const animateEntrance = true;

    final Widget listChild;
    if (entries.isEmpty) {
      // The empty↔populated swap is animated by the outer AnimatedSwitcher
      // below. Its layoutBuilder sizes the transition to the INCOMING child
      // and fades the outgoing one out clipped behind it — so the old
      // (taller) list never inflates the shorter empty state mid-flight
      // (the "banner grows" bug that forced an instant swap before).
      listChild = RepaintBoundary(
        child: RefreshIndicator(
          key: const ValueKey('empty'),
          onRefresh: onRefresh,
          child: ListView(
          scrollCacheExtent: const ScrollCacheExtent.pixels(600),
          // Same horizontal padding as the populated list, so the
          // practice-of-the-day header keeps the EXACT same width (and
          // height) whether the category has entries or not. Without it
          // the header rendered full-bleed (504px vs 472px) and its text
          // re-wrapped — the banner visually "grew" on empty categories.
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          children: [
            ?header,
            // Compact empty state — a fixed, modest height instead of
            // 60% of the screen. The old giant block made the section
            // "grow" when switching to an empty category (e.g. Random
            // with no matches) — the practice-of-the-day card seemed to
            // inflate because a 500px empty well appeared beneath it.
            SizedBox(
              height: 220,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [scheme.primary, scheme.tertiary],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.28),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      emptyText,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      );
    } else {
      // Wrap with RepaintBoundary to isolate list repaints from the rest
      // of the UI.
      listChild = RepaintBoundary(
      child: RefreshIndicator(
        key: const ValueKey('populated'),
        onRefresh: onRefresh,
        child: ReorderableListView.builder(
          scrollCacheExtent: const ScrollCacheExtent.pixels(900),
          // Top padding kept minimal so the pills and the first card sit
          // close together (the pills row already provides its own 4px).
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          header: header,
          onReorderItem: onReorder ?? (_, _) {},
          buildDefaultDragHandles: false,
          // Keep the dragged item visually rounded. Without this proxyDecorator,
          // Flutter lifts each child on a rectangular Material that erases the
          // card's rounded corners — the floating "ghost" looked like a sharp
          // rectangle slid over a round list. Here we re-wrap the child in a
          // rounded Material that scales subtly as the drag engages.
          proxyDecorator: (child, index, animation) {
            // Wrap the dragged child in a rounded Material + ClipRRect so
            // the active list card retains rounded corners during the lift
            // (without this the dragged "ghost" was a sharp rectangle that
            // visibly erased the card's radius). Elevation 8 + tinted
            // shadow do the lifting; no Transform.scale — scaling would
            // smear the elevation halo and look detached from the list.
            final scheme = Theme.of(context).colorScheme;
            return Material(
              elevation: 8,
              color: Colors.transparent,
              shadowColor: scheme.primary.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: child,
              ),
            );
          },
          itemCount: entries.length,
          // Lazy item builder — cards (and their markdown previews) are only
          // built for what's actually visible, instead of eagerly building
          // every entry on every list build.
          itemBuilder: (context, i) => _EntryCard(
            key: ValueKey(entries[i].id),
            index: i,
            entry: entries[i],
            heroTag: '$heroPrefix-${entries[i].id}',
            animate: animateEntrance,
            onTap: () => onTap(entries[i]),
            onPin: () => onPin(entries[i]),
          ),
          footer: const _MadeWithLove(key: ValueKey('footer')),
        ),
      ),
      );
    }

    // Smooth empty↔populated transition (search clearing to "Записей пока
    // нет", category/day filter switches): a 260ms cross-fade sized to the
    // incoming child, so the swap reads as one soft dissolve.
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) => ClipRect(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Outgoing children are Positioned so they NEVER inflate the
              // Stack's size (Stack sizes to non-positioned children only) —
              // the incoming child defines the section height alone.
              ...previousChildren.map((w) => Positioned.fill(child: w)),
              ?currentChild,
            ],
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(entries.isEmpty ? 'section-empty' : 'section-list'),
          child: listChild,
        ),
      ),
    );
  }
}
