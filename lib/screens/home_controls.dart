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
/// A fixed-size icon keeps the toolbar from moving between states, and the
/// glass/X pair cross-fades cleanly (no tooltip).
class _SearchToggleButton extends StatefulWidget {
  final bool isSearching;
  final VoidCallback onTap;

  const _SearchToggleButton({required this.isSearching, required this.onTap});

  @override
  State<_SearchToggleButton> createState() => _SearchToggleButtonState();
}

class _SearchToggleButtonState extends State<_SearchToggleButton> {
  @override
  Widget build(BuildContext context) {
    return PressableIconButton(
      onPressed: widget.onTap,
      // Clean cross-fade between the search glass and the X. The earlier
      // rotation + easeOutBack version overshot the icon scale and flashed
      // a big blurry block on low-end GPUs — a plain fade is smooth on all
      // devices. The press itself is a soft, shallow dimple with a faint halo.
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: Icon(
          key: ValueKey(widget.isSearching),
          widget.isSearching ? Icons.close_rounded : Icons.search_rounded,
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
      // One eased transition keeps opacity, scale, and position in sync.
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      offset: visible ? Offset.zero : const Offset(0, 1.25),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
        scale: visible ? 1.0 : 0.9,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic,
          opacity: visible ? 1.0 : 0.0,
          child: IgnorePointer(ignoring: !visible, child: child),
        ),
      ),
    );
  }
}

/// The circular "＋" button. A StatefulWidget so the press gives a tactile
/// *dimple* — the whole disc dips to 0.96 with a soft halo while the finger
/// is down, and glides back over 360ms on release. Way smoother than the stock
/// InkWell highlight, and the haptics are only fired once per press.
class _PressFab extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _PressFab({required this.onTap, this.onLongPress});

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
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              _wasLong = true;
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        // Fast dimple, slower eased-out recoil (see PressScale) — the release
        // should feel like a spring settling, not a snap.
        duration: _pressed
            ? const Duration(milliseconds: 120)
            : const Duration(milliseconds: 360),
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

  /// Ids of entries whose entrance animation already played this session.
  /// The lazy list disposes off-screen cards, so without this every card that
  /// scrolled out and back replayed its fade+slide — the "записи дёргает и
  /// мигает" flicker. Shared with the parent so the memory outlives the list.
  final Set<String>? seenEntranceIds;

  final int movementRevision;
  final int filterRevision;
  final Map<String, _EntryCardPosition> movementPositions;

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
    this.seenEntranceIds,
    this.movementRevision = 0,
    this.filterRevision = 0,
    required this.movementPositions,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Keep the empty state inside the same list/header layout as populated
    // results; animate its height and opacity without moving the whole feed.
    final emptyState = SizedBox(
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
    );
    final listHeader = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?header,
        AnimatedSize(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: entries.isEmpty
                ? KeyedSubtree(key: const ValueKey('empty'), child: emptyState)
                : const SizedBox.shrink(key: ValueKey('populated')),
          ),
        ),
      ],
    );

    // Isolate list repaints from the rest of the screen.
    return RepaintBoundary(
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical) {
            _shiftEntryCardPositions(
              movementPositions,
              notification.scrollDelta ?? 0,
              keyPrefix: '$heroPrefix-',
            );
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ReorderableListView.builder(
            scrollCacheExtent: const ScrollCacheExtent.pixels(900),
            // Keep the pills and first card close together.
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            header: listHeader,
            onReorderItem: onReorder ?? (_, _) {},
            buildDefaultDragHandles: false,
            proxyDecorator: (child, index, animation) {
              // Preserve the card's rounded shape while it is dragged.
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
            // Build cards lazily; their entrance animation is one-shot per ID.
            itemBuilder: (context, i) {
              final entry = entries[i];
              return _EntryCard(
                key: ValueKey(entry.id),
                index: i,
                entry: entry,
                heroTag: '$heroPrefix-${entry.id}',
                animate:
                    filterRevision == 0 &&
                    (seenEntranceIds == null || seenEntranceIds!.add(entry.id)),
                movementRevision: movementRevision,
                filterRevision: filterRevision,
                movementPositions: movementPositions,
                onTap: () => onTap(entry),
                onPin: () => onPin(entry),
              );
            },
            footer: entries.isEmpty
                ? null
                : const _MadeWithLove(key: ValueKey('footer')),
          ),
        ),
      ),
    );
  }
}
