import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ataraxy/l10n/strings.dart';
import 'package:ataraxy/widgets/skeleton.dart';
import 'package:ataraxy/models/favorite_activity.dart';
import 'package:ataraxy/services/favorite_activity_service.dart';
import 'package:ataraxy/theme/app_theme.dart';
import 'package:ataraxy/widgets/limited_context_menu.dart';
import 'package:ataraxy/widgets/em_dash_formatter.dart';
import 'package:ataraxy/widgets/animated_snack.dart';

class FavoriteActivityScreen extends StatefulWidget {
  const FavoriteActivityScreen({super.key});

  static const int maxLength = FavoriteActivityService.maxLength;
  static const int maxItems = FavoriteActivityService.maxItems;

  @override
  State<FavoriteActivityScreen> createState() => _FavoriteActivityScreenState();
}

class _FavoriteActivityScreenState extends State<FavoriteActivityScreen> {
  final _service = FavoriteActivityService();
  List<FavoriteActivity> _items = [];
  bool _loading = true;
  // The id of the card that should play its entrance animation (just
  // added). Cleared on the next full reload so edits and pin-toggles
  // don't re-animate existing cards.
  String? _justAddedId;
  // Items removed from [_items] but still fading out — rendered above the
  // live list so the exit animation plays even if a reload lands mid-fade
  // (the old code let a reload resurrect a "deleted" card).
  final List<FavoriteActivity> _exiting = [];
  // Hide the FAB while scrolling down, show it again on scroll up.
  final ValueNotifier<bool> _fabVisible = ValueNotifier(true);
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fabVisible.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n is ScrollUpdateNotification && n.dragDetails != null) {
      final delta = n.metrics.pixels - _lastScrollOffset;
      if (delta.abs() < 2) return false;
      _lastScrollOffset = n.metrics.pixels;
      if (delta > 0 && _fabVisible.value) _fabVisible.value = false;
      if (delta < 0 && !_fabVisible.value) _fabVisible.value = true;
    }
    return false;
  }

  Future<void> _load() async {
    final list = await _service.load();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
      _justAddedId = null;
      // Keep fading-out cards animating; only drop them once their fade
      // finished (handled in _delete).
      _exiting.removeWhere((a) => !list.any((b) => b.id == a.id));
    });
  }

  FavoriteActivity? get _featured {
    if (_items.isEmpty) return null;
    for (final a in _items) {
      if (a.pinned) return a;
    }
    return _items.first;
  }

  Future<void> _add() async {
    if (_items.length >= FavoriteActivityScreen.maxItems) {
      AnimatedSnack.show(
        context,
        L.tr(context, 'favoriteActivityLimitReached'),
        type: SnackType.warning,
      );
      return;
    }
    final result = await _editItem(null);
    if (result != null) {
      final added = await _service.add(result);
      if (!added && mounted) {
        AnimatedSnack.show(
          context,
          L.tr(context, 'favoriteActivityLimitReached'),
          type: SnackType.warning,
        );
        return;
      }
      if (!mounted) return;
      // Optimistic insert — the new card mounts with a fade+slide entrance
      // instead of the whole list being reloaded and swapping in abruptly.
      setState(() {
        _items.insert(0, result);
        _justAddedId = result.id;
      });
      AnimatedSnack.show(
        context,
        L.tr(context, 'favoriteActivityAdded'),
        type: SnackType.success,
      );
    }
  }

  Future<void> _edit(FavoriteActivity item) async {
    final result = await _editItem(item);
    if (result != null) {
      await _service.update(result);
      await _load();
    }
  }

  Future<void> _delete(FavoriteActivity item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L.tr(context, 'deleteTitle')),
        content: Text(L.tr(context, 'deleteContent')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(L.tr(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(L.tr(context, 'favoriteActivityDelete')),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    // Remove from the store FIRST so a concurrent reload can never
    // resurrect the card (the old order let "deleted" items return).
    await _service.delete(item.id);
    if (!mounted) return;
    // Then drop it from the live list and keep it in [_exiting] while the
    // fade-out plays; it is removed from [_exiting] once the animation
    // finishes, so the card glides away instead of snapping.
    setState(() {
      _items.removeWhere((a) => a.id == item.id);
      _exiting.add(item);
    });
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    setState(() => _exiting.removeWhere((a) => a.id == item.id));
    AnimatedSnack.show(
      context,
      L.tr(context, 'favoriteActivityDeleted'),
      type: SnackType.success,
    );
  }

  Future<FavoriteActivity?> _editItem(FavoriteActivity? existing) async {
    return showModalBottomSheet<FavoriteActivity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _EditActivitySheet(
          initial: existing,
          onCancel: () => Navigator.of(ctx).pop(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final featured = _featured;

    return Scaffold(
      body: _loading
          ? const SkeletonList(count: 5)
          : NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: scheme.surface,
                  surfaceTintColor: Colors.transparent,
                  foregroundColor: scheme.onSurface,
                  title: Text(L.tr(context, 'favoriteActivities')),
                ),
                if (featured != null)
                  SliverToBoxAdapter(
                    child: _ReadingMode(
                      activity: featured,
                      onEdit: () => _edit(featured),
                      onPin: () async {
                        await _service.togglePin(featured.id);
                        await _load();
                      },
                      onHoldDelete: () => _delete(featured),
                    ),
                  ),
                if (_items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(onAdd: _add),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    sliver: SliverList.builder(
                      // Fading-out cards render above the live list so the
                      // exit animation plays even if a reload lands mid-fade.
                      itemCount: _exiting.length + _items.length,
                      itemBuilder: (_, i) {
                        if (i < _exiting.length) {
                          final a = _exiting[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _AnimatedActivityCard(
                              animateIn: false,
                              exiting: true,
                              child: _ActivityCard(
                                activity: a,
                                onEdit: () => _edit(a),
                                onDelete: () => _delete(a),
                                onPin: () async {
                                  await _service.togglePin(a.id);
                                  await _load();
                                },
                              ),
                            ),
                          );
                        }
                        final a = _items[i - _exiting.length];
                        // The featured one is already rendered as the
                        // prominent reading-mode card above - skip it here
                        // so the user is not seeing the same item twice.
                        if (featured != null && featured.id == a.id) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: i < _items.length - 1 ? 10 : 0,
                          ),
                          // Fade+slide entrance for a freshly added card.
                          child: _AnimatedActivityCard(
                            animateIn: a.id == _justAddedId,
                            exiting: false,
                            child: _ActivityCard(
                              activity: a,
                              onEdit: () => _edit(a),
                              onDelete: () => _delete(a),
                              onPin: () async {
                                await _service.togglePin(a.id);
                                await _load();
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
            ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _fabVisible,
        builder: (context, v, child) => AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          offset: v ? Offset.zero : const Offset(0, 2.2),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 240),
            opacity: v ? 1.0 : 0.0,
            child: IgnorePointer(ignoring: !v, child: child),
          ),
        ),
        child: FloatingActionButton.extended(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          onPressed: _add,
          icon: const Icon(Icons.add_rounded),
          label: Text(L.tr(context, 'favoriteActivityAdd')),
        ),
      ),
    );
  }
}

/// The prominent reading-mode card for the main (first/pinned) activity.
/// Tapping a big "hold to delete" pill for 10 s deletes it — deliberately
/// WITHOUT an always-visible trash icon (the featured card is the safest
/// place to require a deliberate long-press).
class _ReadingMode extends StatefulWidget {
  final FavoriteActivity activity;
  final VoidCallback onEdit;
  final VoidCallback onPin;
  final VoidCallback onHoldDelete;

  const _ReadingMode({
    required this.activity,
    required this.onEdit,
    required this.onPin,
    required this.onHoldDelete,
  });

  @override
  State<_ReadingMode> createState() => _ReadingModeState();
}

class _ReadingModeState extends State<_ReadingMode>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(seconds: 10);
  late final AnimationController _holdCtrl;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _holdCtrl = AnimationController(vsync: this, duration: _holdDuration);
  }

  void _onHoldStart() {
    if (_holding) return;
    setState(() => _holding = true);
    _holdCtrl.forward().then((_) {
      if (!mounted || !_holding) return;
      _holding = false;
      widget.onHoldDelete();
    });
  }

  void _onHoldEnd() {
    if (!_holding) return;
    _holdCtrl.stop();
    setState(() => _holding = false);
    _holdCtrl.value = 0;
  }

  @override
  void dispose() {
    _holdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: GestureDetector(
        onLongPressStart: (_) => _onHoldStart(),
        onLongPressEnd: (_) => _onHoldEnd(),
        onLongPressCancel: _onHoldEnd,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primaryContainer, scheme.secondaryContainer],
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.activity.pinned
                          ? Icons.push_pin_rounded
                          : Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    L.tr(context, 'favoriteActivityReading'),
                    style: TextStyle(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: widget.activity.pinned
                        ? L.tr(context, 'favoriteActivityUnpin')
                        : L.tr(context, 'favoriteActivityPin'),
                    icon: Icon(
                      widget.activity.pinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      color: scheme.primary,
                    ),
                    onPressed: widget.onPin,
                  ),
                  IconButton(
                    tooltip: L.tr(context, 'favoriteActivityEdit'),
                    icon: Icon(Icons.edit_rounded, color: scheme.primary),
                    onPressed: widget.onEdit,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Big typography reading-mode look
              Text(
                widget.activity.text,
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontSize: 26,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.format_quote_rounded,
                    size: 20,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.activity.text.length} / '
                    '${FavoriteActivityScreen.maxLength} '
                    '${L.tr(context, 'favoriteActivityLimit')}',
                    style: TextStyle(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              // Hold-to-delete: a thin progress bar + label that appear
              // ONLY while holding — no always-visible delete icon.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: _holding
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                // AnimatedBuilder: the bar must repaint as
                                // _holdCtrl advances — without it the value
                                // was read once at build and froze at 0.
                                child: AnimatedBuilder(
                                  animation: _holdCtrl,
                                  builder: (context, _) =>
                                      LinearProgressIndicator(
                                        value: _holdCtrl.value,
                                        minHeight: 5,
                                        backgroundColor: scheme
                                            .onPrimaryContainer
                                            .withValues(alpha: 0.12),
                                        color: scheme.error,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              L.tr(context, 'favoriteActivityHoldDelete'),
                              style: TextStyle(
                                color: scheme.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fade+slide wrapper for list cards: plays a smooth entrance when
/// [animateIn] is true (freshly added item) and a fade-out when [exiting]
/// is true (item being deleted). All other cards render statically — no
/// controller overhead on scroll or reload.
class _AnimatedActivityCard extends StatefulWidget {
  final bool animateIn;
  final bool exiting;
  final Widget child;

  const _AnimatedActivityCard({
    required this.animateIn,
    required this.exiting,
    required this.child,
  });

  @override
  State<_AnimatedActivityCard> createState() => _AnimatedActivityCardState();
}

class _AnimatedActivityCardState extends State<_AnimatedActivityCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.animateIn ? 0.0 : 1.0,
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    if (widget.animateIn) _ctrl.forward();
    // A card mounted with exiting:true (fading-out list) must glide away
    // immediately — it starts visible and reverses on first frame.
    if (widget.exiting) _ctrl.reverse();
  }

  @override
  void didUpdateWidget(_AnimatedActivityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.exiting && widget.exiting) {
      _ctrl.reverse();
    }
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
      // Collapse the card's height WHILE it fades out so the cards below
      // glide up smoothly — without this the removed card left a gap that
      // snapped shut, which read as a jerky jump with 4+ items.
      child: SizeTransition(
        sizeFactor: CurvedAnimation(
          parent: _ctrl,
          curve: Curves.easeInOutCubic,
        ),
        alignment: Alignment.topCenter,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}

class _ActivityCard extends StatefulWidget {
  final FavoriteActivity activity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPin;

  const _ActivityCard({
    required this.activity,
    required this.onEdit,
    required this.onDelete,
    required this.onPin,
  });

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  FavoriteActivity get activity => widget.activity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: widget.onEdit,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.text,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${activity.text.length} / '
                          '${FavoriteActivityScreen.maxLength}',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        if (activity.pinned) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.push_pin_rounded,
                            size: 12,
                            color: AppAccents.amber.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            L.tr(context, 'pinned'),
                            style: TextStyle(
                              color: AppAccents.amber.withValues(alpha: 0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: activity.pinned
                    ? L.tr(context, 'favoriteActivityUnpin')
                    : L.tr(context, 'favoriteActivityPin'),
                icon: Icon(
                  activity.pinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  color: activity.pinned ? AppAccents.amber : scheme.primary,
                  size: 20,
                ),
                onPressed: widget.onPin,
              ),
              IconButton(
                tooltip: L.tr(context, 'delete'),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppAccents.danger,
                  size: 20,
                ),
                onPressed: widget.onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, scheme.secondary],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.spa_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              L.tr(context, 'favoriteActivityEmpty'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              L.tr(context, 'favoriteActivityEmptyHint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(L.tr(context, 'favoriteActivityAdd')),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditActivitySheet extends StatefulWidget {
  final FavoriteActivity? initial;
  final VoidCallback onCancel;
  const _EditActivitySheet({required this.initial, required this.onCancel});

  @override
  State<_EditActivitySheet> createState() => _EditActivitySheetState();
}

class _EditActivitySheetState extends State<_EditActivitySheet> {
  late final TextEditingController _controller;
  bool _pinned = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial?.text ?? '');
    _pinned = widget.initial?.pinned ?? false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final activity =
        (widget.initial ??
                FavoriteActivity(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  text: text,
                  createdAt: DateTime.now(),
                ))
            .copyWith(text: text, pinned: _pinned);
    Navigator.of(context).pop(activity);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final maxLength = FavoriteActivityScreen.maxLength;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 6, bottom: 14),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              widget.initial == null
                  ? L.tr(context, 'favoriteActivityAdd')
                  : L.tr(context, 'favoriteActivityEdit'),
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
        cursorOpacityAnimates: true,
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
              controller: _controller,
              autofocus: true,
              maxLength: maxLength,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              // Hyphens typed as punctuation become em dashes automatically.
              inputFormatters: const [EmDashInputFormatter()],
              contextMenuBuilder: (ctx, state) =>
                  buildLimitedContextMenu(ctx, state),
              decoration: InputDecoration(
                hintText: L.tr(context, 'favoriteActivityHint'),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                counterStyle: TextStyle(
                  color: _controller.text.length >= maxLength
                      ? AppAccents.danger
                      : scheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Switch(
                  value: _pinned,
                  onChanged: (v) => setState(() => _pinned = v),
                ),
                const SizedBox(width: 4),
                Text(
                  _pinned
                      ? L.tr(context, 'favoriteActivityPin')
                      : L.tr(context, 'favoriteActivityUnpin'),
                  style: TextStyle(color: scheme.onSurface, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: widget.onCancel,
                    child: Text(L.tr(context, 'cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _controller.text.trim().isEmpty ? null : _save,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(L.tr(context, 'save')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
