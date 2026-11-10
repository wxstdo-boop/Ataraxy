import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ataraxy/l10n/strings.dart';
import 'package:ataraxy/widgets/animated_field_counter.dart';
import 'package:ataraxy/widgets/pressable_icon_button.dart';
import 'package:ataraxy/models/entry.dart';
import 'package:ataraxy/models/settings.dart';
import 'package:ataraxy/providers/settings_provider.dart';
import 'package:ataraxy/services/storage_service.dart';
import 'package:ataraxy/theme/app_theme.dart';
import 'package:ataraxy/ai_overlay_state.dart';
import 'package:ataraxy/screens/entry_screen.dart';
import 'package:ataraxy/screens/entry_detail_screen.dart';
import 'package:ataraxy/screens/favorite_activity_screen.dart';
import 'package:ataraxy/screens/settings_screen.dart';
import 'package:ataraxy/screens/statistics_screen.dart';
import 'package:ataraxy/screens/favorites_screen.dart';
import 'package:ataraxy/screens/daily_guide_screen.dart';
import 'package:ataraxy/widgets/reminder_dialog.dart';
import 'package:ataraxy/widgets/animated_snack.dart';
import 'package:ataraxy/widgets/app_route.dart';
import 'package:ataraxy/services/notification_service.dart';
import 'package:ataraxy/data/daily_prompts.dart' as dp;
import 'package:ataraxy/widgets/limited_context_menu.dart';
import 'package:ataraxy/widgets/em_dash_formatter.dart';
import 'package:ataraxy/widgets/premium_header.dart';
import 'package:ataraxy/widgets/skeleton.dart';
import 'package:ataraxy/widgets/streak_badge.dart';

part 'home_tab_bar.dart';
part 'home_controls.dart';
part 'home_banners.dart';
part 'home_notes.dart';
part 'home_entry_card.dart';

/// Cached blur filters: BackdropFilter re-creating its engine-level shader on
/// every rebuild is wasteful on low-end devices. One shared instance per look,
/// zero visual difference. Sigma kept modest (7) — soft enough for the frosted
/// glass, cheap enough to keep 60fps on a Redmi Note 12 while the feed scrolls.
final ImageFilter _kBarBlur = ImageFilter.blur(sigmaX: 7, sigmaY: 7);
final ImageFilter _kSearchBlur = ImageFilter.blur(sigmaX: 8, sigmaY: 8);

/// Every card animates in when it first appears (new entry id = new
/// element). Cards are keyed by entry id, so filtering (search, category
/// chips) re-creates only the cards that actually changed — those fade in
/// softly instead of popping, while cards already on screen keep their
/// state and never re-animate.

class HomeScreen extends StatefulWidget {
  final VoidCallback? onRequestLock;
  final bool tulpaEnabled;

  const HomeScreen({super.key, this.onRequestLock, this.tulpaEnabled = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  static const String _blurPrefKey = 'title_blurred';
  List<JournalEntry> _entries = [];
  /// Days in a row the user wrote at least one entry (ends today, or
  /// yesterday while today is still empty so the streak isn't "broken"
  /// before the day is over). Shown in the header StreakBadge.
  int _streak = 0;
  bool _loading = true;
  bool _searching = false;
  bool _refreshing = false;
  bool _blurred = false;
  EntryCategory _category = EntryCategory.none;
  int _sortMode = 0; // 0=newest, 1=oldest, 2=alpha, -1=manual
  // Timestamp of the last "Записи обновлены" snackbar — rapid refresh
  // taps are debounced so the snackbar doesn't stack.
  DateTime _lastRefreshSnackAt = DateTime.fromMillisecondsSinceEpoch(0);
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  // When the user scrolls a list DOWN the FAB + reminders button glide out
  // of the way; scrolling up brings them back. Works for every tab (dreams,
  // life, tulpas, all) via bubbling scroll notifications.
  final ValueNotifier<bool> _fabVisible = ValueNotifier(true);
  double _lastScrollOffset = 0;
  // The pill bars (main sections + category chips) retract into the header
  // while the user scrolls down and glide back on scroll-up / back-at-top.
  // ONE controller drives BOTH bars as a single choreography; every frame of
  // the collapse updates the app-bar's bottom height (preferredSize).
  late final AnimationController _barsCtrl;
  late final Animation<double> _barsAnim;
  /// 1 = bars fully expanded, 0 = fully retracted.
  double get _barsT => _barsAnim.value;
  /// Bumped by every rebuild that changes the feed. Bar-collapse ticks go
  /// through [_onBarsTick] and leave it alone — that is what lets [_StableFeed]
  /// hand back its cached widget while the pills retract.
  int _contentRev = 0;
  // The AI assistant is a plain widget mounted in this screen's Stack (NOT
  // a root-overlay OverlayEntry — that architecture caused the grey-screen
  // crash loop on this device). Long-pressing "+" toggles it; a second
  // long-press runs the assistant's animated close (fade+scale) instead of
  // a hard unmount.
  // The AI assistant lives at the AppShell level (above the Navigator) so
  // it floats over every section; the FAB long-press just flips the shared
  // visibility notifier.


  @override
  void initState() {
    super.initState();
    _load();
    _loadBlurPref();
    _searchFocus.addListener(_onSearchFocusChanged);
    // Убираем фокус при инициализации чтобы избежать автовызова клавиатуры
    _searchFocus.unfocus();
    _barsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      value: 1.0,
    );
    _barsAnim = CurvedAnimation(
      parent: _barsCtrl,
      curve: Curves.easeInOutCubic,
    );
    _barsCtrl.addListener(_onBarsTick);
  }

  /// Each frame of the collapse rebuilds the screen: the app bar reserves its
  /// bottom slot from `preferredSize`, which is only re-read on a Scaffold
  /// rebuild. Goes through `super.setState` so [_contentRev] stays put and the
  /// feed subtree is not rebuilt — only the two bars are.
  void _onBarsTick() {
    if (mounted) super.setState(() {});
  }

  @override
  void setState(VoidCallback fn) {
    _contentRev++;
    super.setState(fn);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _contentRev++;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _contentRev++;
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_onSearchFocusChanged);
    _searchFocus.dispose();
    _fabVisible.dispose();
    _barsCtrl.removeListener(_onBarsTick);
    _barsCtrl.dispose();
    super.dispose();
  }

  /// Hides/shows the FAB + reminders while the user drags a list: scroll
  /// down → hide, scroll up → show. Reacts only to real user drags and
  /// ignores tiny jitter.
  bool _onScrollNotification(ScrollNotification n) {
    // VERTICAL drags only: swiping the category chips row sideways is a
    // horizontal scroll and must NOT hide the bars/FAB (it used to, because
    // any axis produced a positive pixels delta).
    if (n is! ScrollUpdateNotification || n.metrics.axis != Axis.vertical) {
      return false;
    }
    final delta = n.metrics.pixels - _lastScrollOffset;
    _lastScrollOffset = n.metrics.pixels;
    // Back at the very top (drag or fling) — always restore everything.
    if (n.metrics.pixels <= 0) {
      if (!_fabVisible.value) _fabVisible.value = true;
      if (!_barsCtrl.isCompleted) _barsCtrl.forward();
      return false;
    }
    // Momentum (ballistic) frames keep the previous decision: only real
    // user drags toggle the bars.
    if (n.dragDetails == null) return false;
    if (delta.abs() < 2) return false;
    if (delta > 0) {
      // Scrolling down: tuck the FAB and both pill-bars away.
      if (_fabVisible.value) _fabVisible.value = false;
      if (!_barsCtrl.isDismissed) _barsCtrl.reverse();
    } else {
      // Scrolling up: bring everything back.
      if (!_fabVisible.value) _fabVisible.value = true;
      if (!_barsCtrl.isCompleted) _barsCtrl.forward();
    }
    return false;
  }

  void _onSearchFocusChanged() {
    if (!_searchFocus.hasFocus && _searchQuery.isEmpty) {
      setState(() => _searching = false);
    }
  }

  Future<void> _loadBlurPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _blurred = prefs.getBool(_blurPrefKey) ?? false;
    });
  }

  Future<void> _persistBlurPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_blurPrefKey, value);
  }

  Future<void> _load() async {
    if (!_loading && !_refreshing) {
      setState(() => _refreshing = true);
    }
    try {
      final entries = await _storage.loadEntries();
      final order = await _storage.loadManualOrder();
      if (!mounted) return;
      setState(() {
        _entries = _applyManualOrder(entries, order);
        _streak = _computeStreak(entries);
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _entries = [];
        _loading = false;
        _refreshing = false;
      });
    }
  }

  /// The decoder always returns entries newest-first, so a dragged order
  /// would snap back on the next reload unless it is re-applied from disk.
  /// Ids the box no longer has are dropped; entries it gained (a new note,
  /// a restored backup) keep their newest-first order at the tail.
  List<JournalEntry> _applyManualOrder(
    List<JournalEntry> entries,
    List<String> order,
  ) {
    if (order.isEmpty) return entries;
    final byId = <String, JournalEntry>{for (final e in entries) e.id: e};
    final out = <JournalEntry>[];
    for (final id in order) {
      final e = byId.remove(id);
      if (e != null) out.add(e);
    }
    out.addAll(byId.values);
    return out;
  }

  /// Counts consecutive days (ending today, or yesterday while today is
  /// still empty) that contain at least one entry.
  int _computeStreak(List<JournalEntry> entries) {
    if (entries.isEmpty) return 0;
    final days = <int>{};
    for (final e in entries) {
      final d = e.createdAt;
      days.add(DateTime(d.year, d.month, d.day).millisecondsSinceEpoch);
    }
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    // While today is still empty, count from yesterday so a fresh morning
    // doesn't instantly reset the streak.
    if (!days.contains(cursor.millisecondsSinceEpoch)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (days.contains(cursor.millisecondsSinceEpoch)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Per-build cache: [build] asks for the same tab type several times
  /// (banner + list + reorder callback), and each [filtered] pass re-runs
  /// the category/search filter AND a full sort. Caching per build cuts
  /// that to one pass per type instead of three.
  final Map<EntryType?, List<JournalEntry>> _filteredCache = {};

  List<JournalEntry> _filtered(EntryType? type) {
    return _filteredCache.putIfAbsent(type, () {
      var list = type == null
          ? _entries
          : _entries.where((e) => e.type == type).toList();
      if (_category != EntryCategory.none) {
        list = list.where((e) => e.category == _category).toList();
      }
      final query = _searchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        list = list.where((e) {
          if (e.title.toLowerCase().contains(query)) return true;
          if (e.content.toLowerCase().contains(query)) return true;
          if (e.tags.any((t) => t.toLowerCase().contains(query))) return true;
          return false;
        }).toList();
      }
      // Sort pinned entries to the top, then apply sort mode
      if (_sortMode == -1) {
        // Manual order: position in _entries. Build an id→index map ONCE
        // instead of calling _entries.indexOf inside the comparator (that
        // was O(n) per comparison → O(n² log n) on long lists).
        final pos = <String, int>{};
        for (var i = 0; i < _entries.length; i++) {
          pos[_entries[i].id] = i;
        }
        list = List.of(list);
        list.sort((a, b) {
          if (b.pinned && !a.pinned) return 1;
          if (!b.pinned && a.pinned) return -1;
          return (pos[a.id] ?? 0).compareTo(pos[b.id] ?? 0);
        });
      } else {
        list = List.from(list)
          ..sort((a, b) {
            if (b.pinned && !a.pinned) return 1;
            if (!b.pinned && a.pinned) return -1;
            if (_sortMode == 1) return a.updatedAt.compareTo(b.updatedAt);
            if (_sortMode == 2) return a.title.compareTo(b.title);
            return b.updatedAt.compareTo(a.updatedAt);
          });
      }
      return list;
    });
  }

  /// Clears the per-build filter cache at the start of every build, so
  /// each frame recomputes at most one pass per visible tab type.
  void _beginBuild() {
    _filteredCache.clear();
  }

  Future<void> _togglePin(JournalEntry entry) async {
    // Patch the flag on disk instead of writing the object the feed happens
    // to be holding: that snapshot can predate an autosave from the editor,
    // and persisting it silently reverts the user's newest words.
    await _storage.patchEntry(entry.id, {'pinned': !entry.pinned});
    await _load();
  }

  void _onReorder(List<JournalEntry> list, int oldIndex, int newIndex) {
    final id = list[oldIndex].id;
    final oldPos = _entries.indexWhere((e) => id == e.id);
    if (oldPos < 0) return;
    final item = _entries.removeAt(oldPos);
    final targetId = newIndex < list.length ? list[newIndex].id : null;
    final insertPos = targetId == null
        ? _entries.length
        : _entries.indexWhere((e) => e.id == targetId);
    _entries.insert(insertPos < 0 ? _entries.length : insertPos, item);
    _sortMode = -1;
    // Only the id sequence is persisted. Rewriting every entry from memory
    // (the old saveEntries call) raced the editor's autosave and pushed
    // stale bodies back to the box — the "my words disappeared" bug.
    unawaited(
      _storage.saveManualOrder(_entries.map((e) => e.id).toList()),
    );
    setState(() {});
  }

  void _openEditor() {
    if (!mounted) return;
    // Short, smooth fade (280ms) instead of the stock page route — the editor
    // appears without the extra beat of room the default transition waits for.
    Navigator.of(
      context,
    ).push(fadeRoute(const EntryScreen())).then((_) {
      if (mounted) _load();
    });
  }

  void _openAiAssistant() {
    // Toggle: long-pressing "+" opens the floating chat, pressing again
    // closes it. The assistant's own X button animates the close; the FAB
    // toggle just flips the shared visibility (the fade still plays when
    // reopening since the widget is recreated from the closed state).
    // When the assistant is turned OFF in Settings, the long-press must
    // NOT summon it — just a friendly warning snack instead.
    final sp = SettingsProvider.of(context);
    if (!sp.settings.aiEnabled) {
      AnimatedSnack.show(
        context,
        L.tr(context, 'aiDisabled'),
        type: SnackType.warning,
      );
      return;
    }
    aiOverlayOpen.value = !aiOverlayOpen.value;
  }

  Future<void> _openDetail(JournalEntry entry, {String heroPrefix = ''}) async {
    final changed = await Navigator.of(context).push<bool>(
      fadeRoute(
        EntryDetailScreen(
          entry: entry,
          storage: _storage,
          heroPrefix: heroPrefix,
          onRestored: () => _load(),
        ),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    _beginBuild();
    final scheme = Theme.of(context).colorScheme;
    final headerBg =
        Theme.of(context).appBarTheme.backgroundColor ?? scheme.primary;

    final tulpaOn = widget.tulpaEnabled;

    final defs = <(String, EntryType?, String)>[
      (
        L.tr(context, 'tabDreams'),
        EntryType.dream,
        L.tr(context, 'emptyDream'),
      ),
      (L.tr(context, 'tabLife'), EntryType.life, L.tr(context, 'emptyLife')),
      if (tulpaOn)
        (
          L.tr(context, 'tabTulpa'),
          EntryType.tulpa,
          L.tr(context, 'emptyTulpa'),
        ),
      (L.tr(context, 'tabAll'), null, L.tr(context, 'emptyAll')),
    ];

    final showRefresh = !_loading && !_refreshing;

    return DefaultTabController(
      length: defs.length,
      child: Scaffold(
        // The keyboard must NOT push the FAB / reminders bar up: search and
        // the AI chat both summon the keyboard, and the floating content
        // would visibly jump. Content is scrollable so nothing gets hidden.
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          // Always white foreground — the gradient AppBar needs white icons
          // and text to be readable regardless of the theme brightness.
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 72,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          flexibleSpace: PremiumHeader(colors: AppTheme.headerColors(scheme)),
          leading: SizedBox(
            width: 48,
            height: 48,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _refreshing
                  ? Center(
                      key: const ValueKey('spinner'),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    )
                  : IconButton(
                      key: const ValueKey('refresh'),
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: L.tr(context, 'refresh'),
                      onPressed: showRefresh
                          ? () {
                              // Reload the entries from storage — the
                              // button previously just waited 2.5s and
                              // locked the screen, which was wrong.
                              _load().then((_) {
                                if (!mounted || !context.mounted) return;
                                // Debounce: rapid taps on refresh must not
                                // stack a "Записи обновлены" snackbar per tap.
                                final now = DateTime.now();
                                if (now.difference(_lastRefreshSnackAt) <
                                    const Duration(seconds: 2)) {
                                  return;
                                }
                                _lastRefreshSnackAt = now;
                                AnimatedSnack.show(
                                  context,
                                  L.tr(context, 'entriesUpdated'),
                                  type: SnackType.success,
                                );
                              });
                            }
                          : null,
                    ),
            ),
          ),
          // Title pinned to the LEFT (as the wordmark was originally), not
          // centered — the streak badge sits right after it.
          titleSpacing: 0,
          title: GestureDetector(
            // Tap hides the title (fade out, no blur); tap again brings it
            // back smoothly.
            onTap: () => setState(() {
              _blurred = !_blurred;
              _persistBlurPref(_blurred);
            }),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              opacity: _blurred ? 0.0 : 1.0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The wordmark stands clean — the winter beanie now sits
                    // on the streak badge (it belongs to the celebration,
                    // not to the static logo).
                    const Text(
                      'Ataraxy',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                        // Explicitly opt OUT of the theme's italic
                        // display font (Cormorant) — the brand wordmark
                        // keeps its original system-sans look.
                        fontFamily: 'sans-serif',
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    const SizedBox(width: 0),
                    // A hair of negative offset tucks the badge right up
                    // against the wordmark (the "y" descender overhangs its
                    // advance box, so the badge visually hugs the text).
                    Transform.translate(
                      offset: const Offset(-3, 0),
                      child: StreakBadge(streak: _streak),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            _SearchToggleButton(
              isSearching: _searching,
              onTap: () {
                if (_searching) {
                  _searchFocus.unfocus();
                  setState(() {
                    _searching = false;
                    _searchQuery = '';
                  });
                } else {
                  setState(() {
                    _searching = true;
                    _searchQuery = '';
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _searchFocus.requestFocus();
                  });
                }
              },
            ),
            PressableIconButton(
              icon: const Icon(Icons.insights_rounded),
              tooltip: L.tr(context, 'statistics'),
              onPressed: () {
                _searchFocus.unfocus();
                Navigator.of(
                  context,
                ).push(fadeRoute(const StatisticsScreen()));
              },
            ),
            PressableIconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: L.tr(context, 'settings'),
              onPressed: () {
                _searchFocus.unfocus();
                Navigator.of(
                  context,
                ).push(fadeRoute(const SettingsScreen())).then((_) => _load());
              },
            ),
          ],
          bottom: _SmoothTabPills(
            labels: defs.map((d) => d.$1).toList(),
            headerColor: headerBg,
            collapse: _barsT,
            onTap: (index) {
              _searchFocus.unfocus();
            },
          ),
        ),
        body: _loading
            ? const SkeletonList()
            : NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: Stack(
                  children: [
                    // Ambient wash behind the feed: a soft theme tint so the
                    // translucent glass cards have something to blend over.
                    // Solid color (not a gradient) — cheaper to composite on
                    // low-end GPUs during scroll.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLowest,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        // Category chips + sort live in ONE compact
                        // pill-bar. It retracts together with the main pill
                        // bar (same driver): scrolling down collapses it into
                        // the header, scrolling up / reaching the top brings
                        // it back — one fluid motion.
                        AnimatedBuilder(
                          animation: _barsAnim,
                          builder: (context, _) {
                            final t = _barsAnim.value;
                            return ClipRect(
                              child: Align(
                                alignment: Alignment.topCenter,
                                heightFactor: t,
                                child: Opacity(
                                  opacity: t,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      6,
                                    ),
                                    child: _CategoryChips(
                                      current: _category,
                                      sortMode: _sortMode,
                                      onChanged: (c) =>
                                          setState(() => _category = c),
                                      onSort: () {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          _sortMode =
                                              _sortMode >= 2
                                                  ? -1
                                                  : _sortMode + 1;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        Expanded(
                          child: _StableFeed(
                            rev: _contentRev,
                            builder: (context) => Stack(
                            children: [
                              TabBarView(
                                // Edge swipes spring back with rubber-band
                                // tension instead of hitting a hard wall (the
                                // "свайп-натяжение" on the first/last tab).
                                physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                ),
                                children: defs
                                    .map(
                                      (d) => d.$2 == EntryType.life
                                          ? _ListSection(
                                              key: ValueKey(
                                                d.$2?.name ?? 'all',
                                              ),
                                              // Favorites banners scroll
                                              // WITH the entries now.
                                              header: Column(
                                                children: [
                                                  _FavoriteActivitiesBanner(
                                                    onTap: () {
                                                      Navigator.of(
                                                        context,
                                                      ).push(
                                                        fadeRoute(
                                                          const FavoriteActivityScreen(),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  _FavoritesBanner(
                                                    onTap: () {
                                                      Navigator.of(context).push(
                                                        fadeRoute(
                                                          const FavoritesScreen(),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                              entries: _filtered(d.$2),
                                              onTap: (e) => _openDetail(
                                                e,
                                                heroPrefix:
                                                    d.$2?.name ?? 'all',
                                              ),
                                              onPin: _togglePin,
                                              onRefresh: _load,
                                              onReorder:
                                                  (oldIdx, newIdx) =>
                                                      _onReorder(
                                                        _filtered(d.$2),
                                                        oldIdx,
                                                        newIdx,
                                                      ),
                                              emptyText: d.$3,
                                            )
                                          : d.$2 == EntryType.dream ||
                                                d.$2 == EntryType.tulpa
                                          ? _ListSection(
                                              key: ValueKey(
                                                d.$2?.name ?? 'all',
                                              ),
                                              header: _DailyGuideBanner(
                                                topic: d.$2 == EntryType.dream
                                                    ? DailyGuideTopic
                                                          .lucidDreams
                                                    : DailyGuideTopic.tulpa,
                                                onTap: () =>
                                                    Navigator.of(
                                                      context,
                                                    ).push(
                                                      fadeRoute(
                                                        DailyGuideScreen(
                                                          topic:
                                                              d.$2 ==
                                                                  EntryType
                                                                      .dream
                                                              ? DailyGuideTopic
                                                                    .lucidDreams
                                                              : DailyGuideTopic
                                                                    .tulpa,
                                                        ),
                                                      ),
                                                    ),
                                              ),
                                              entries: _filtered(d.$2),
                                              onTap: (e) => _openDetail(
                                                e,
                                                heroPrefix:
                                                    d.$2?.name ?? 'all',
                                              ),
                                              onPin: _togglePin,
                                              onRefresh: _load,
                                              onReorder:
                                                  (oldIdx, newIdx) =>
                                                      _onReorder(
                                                        _filtered(d.$2),
                                                        oldIdx,
                                                        newIdx,
                                                      ),
                                              emptyText: d.$3,
                                            )
                                          : () {
                                              // Hide notes (general) from the
                                              // "ВСЕ" tab list — they're only
                                              // reachable via the banner.
                                              final itemsNoNotes =
                                                  _filtered(d.$2)
                                                      .where(
                                                        (e) =>
                                                            e.type !=
                                                            EntryType
                                                                .general,
                                                      )
                                                      .toList();
                                              return _ListSection(
                                                key: ValueKey(
                                                  d.$2?.name ?? 'all',
                                                ),
                                                header: _AllBanner(
                                                  // NOT `_filtered(...)`: the
                                                  // banner hides itself when
                                                  // there are no notes, so a
                                                  // category filter that
                                                  // happens to drop every note
                                                  // used to collapse the header
                                                  // and shift the whole section.
                                                  entries: _entries,
                                                  onTap: () {
                                                    final notes = _entries
                                                        .where(
                                                          (e) =>
                                                              e.type ==
                                                              EntryType
                                                                  .general,
                                                        )
                                                        .toList();
                                                    Navigator.of(context).push(
                                                      fadeRoute(
                                                        _NotesListScreen(
                                                          notes: notes,
                                                          storage: _storage,
                                                          onChanged: _load,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                                heroPrefix:
                                                    d.$2?.name ?? 'all',
                                                entries: itemsNoNotes,
                                                onTap: (e) => _openDetail(
                                                  e,
                                                  heroPrefix:
                                                      d.$2?.name ?? 'all',
                                                ),
                                                onPin: _togglePin,
                                                onRefresh: _load,
                                                onReorder: (oldIdx, newIdx) =>
                                                    _onReorder(
                                                      itemsNoNotes,
                                                      oldIdx,
                                                      newIdx,
                                                    ),
                                                emptyText: d.$3,
                                              );
                                            }(),
                                    )
                                    .toList(),
                              ),
                              AnimatedOpacity(
                                opacity: _refreshing ? 1 : 0,
                                duration: const Duration(milliseconds: 400),
                                child: IgnorePointer(
                                  ignoring: !_refreshing,
                                  child: Container(
                                    color: Colors.white,
                                    child: FadeTransition(
                                      opacity: AlwaysStoppedAnimation(
                                        _refreshing ? 1.0 : 0.0,
                                      ),
                                      child: Center(
                                        child: TweenAnimationBuilder<double>(
                                          duration: const Duration(
                                            milliseconds: 500,
                                          ),
                                          curve: Curves.easeOutBack,
                                          tween: Tween(
                                            begin: 0.7,
                                            end: _refreshing ? 1.0 : 0.7,
                                          ),
                                          builder: (ctx, scale, child) =>
                                              Transform.scale(
                                                scale: scale,
                                                child: child,
                                              ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black,
                                                  shape: BoxShape.circle,
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Colors.black26,
                                                      blurRadius: 22,
                                                      offset: Offset(0, 8),
                                                    ),
                                                  ],
                                                ),
                                                child: ClipOval(
                                                  child: Image.asset(
                                                    'assets/ataraxy.png',
                                                    width: 80,
                                                    height: 80,
                                                    fit: BoxFit.cover,
                                                    cacheWidth: 80,
                                                    cacheHeight: 80,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 18),
                                              Text(
                                                'Ataraxy',
                                                style: TextStyle(
                                                  color: scheme.primary,
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              SizedBox(
                                                width: 28,
                                                height: 28,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: scheme.primary,
                                                      strokeWidth: 3,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: AnimatedSlide(
                        offset: _searching
                            ? Offset.zero
                            : const Offset(0, -0.3),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: _searching ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          child: IgnorePointer(
                            ignoring: !_searching,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: _kSearchBlur,
                                child: Material(
                                  elevation: _searching ? 6 : 0,
                                  borderRadius: BorderRadius.circular(24),
                                  // Frosted glass: the translucent surface
                                  // lets the list behind glow through softly.
                                  color: scheme.surface.withValues(alpha: 0.78),
                                  shadowColor: scheme.primary.withValues(
                                    alpha: 0.25,
                                  ),
                                  child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.search_rounded,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        cursorOpacityAnimates: true,
                                        magnifierConfiguration:
                                            TextMagnifierConfiguration.disabled,
                                        contextMenuBuilder: (ctx, state) =>
                                            buildLimitedContextMenu(ctx, state),
                                        focusNode: _searchFocus,
                                        // Убран autofocus: поле фокусируется только при явном открытии поиска
                                        maxLength: 50,
                                        buildCounter: animatedFieldCounter,
                                        inputFormatters: const [
                                          EmDashInputFormatter(),
                                        ],
                                        onChanged: (value) => setState(
                                          () => _searchQuery = value,
                                        ),
                                        autocorrect: false,
                                        enableSuggestions: false,
                                        style: TextStyle(
                                          color: scheme.onSurface,
                                          fontSize: 16,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: L.tr(context, 'searchHint'),
                                          hintStyle: TextStyle(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _fabVisible,
                        builder: (context, fabVisible, _) => _FadeSlideFab(
                          visible: fabVisible,
                          child: FloatingActionButton(
                            heroTag: 'reminders',
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                            tooltip: L.tr(context, 'reminders'),
                            onPressed: _openReminderDialog,
                            child: const Icon(
                              Icons.notifications_active_rounded,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        // Custom FAB: a single InkWell owns BOTH the tap and the long-press.
        // (Wrapping a FloatingActionButton in a GestureDetector doesn't work —
        // the FAB's own recognizer wins the gesture arena, so the long-press
        // never fires.)
        floatingActionButton: ValueListenableBuilder<bool>(
          valueListenable: _fabVisible,
          builder: (context, fabVisible, _) => _FadeSlideFab(
            visible: fabVisible,
            child: _PressFab(
              onTap: _openEditor,
              onLongPress: _openAiAssistant,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openReminderDialog() async {
    final provider = SettingsProvider.of(context);
    final result = await showDialog<AppSettings>(
      context: context,
      builder: (_) => _ReminderDialog(settings: provider.settings),
    );
    if (result != null && mounted) {
      provider.onChanged(result);
      await NotificationService.updateReminderFromSettings(
        result,
        requestBatteryExemption: result.reminderEnabled,
      );
      if (mounted) {
        if (!context.mounted) return;
        AnimatedSnack.show(
          context,
          L.tr(
            context,
            result.reminderEnabled ? 'reminderSet' : 'reminderDisabled',
          ),
          type: result.reminderEnabled ? SnackType.success : SnackType.info,
        );
      }
    }
  }
}
