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
                                                  color: Colors.white,
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

class _DailyGuideBanner extends StatelessWidget {
  final DailyGuideTopic topic;
  final VoidCallback onTap;

  const _DailyGuideBanner({required this.topic, required this.onTap});

  // Dream prompts imported from data/daily_prompts.dart (~220 entries,
  // enough for 5+ years of unique daily content).

  // Tulpa prompts imported from data/daily_prompts.dart (~200 entries).

  static int _dayIndex(int length) => dp.dailyIndex(length);

  static List<_DailyGuidePrompt> get _dreamPrompts => dp.dreamPrompts;
  static List<_DailyGuidePrompt> get _tulpaPrompts => dp.tulpaPrompts;

  @override
  Widget build(BuildContext context) {
    final isDream = topic == DailyGuideTopic.lucidDreams;
    final prompts = isDream ? _dreamPrompts : _tulpaPrompts;
    final idx = _DailyGuideBanner._dayIndex(prompts.length);
    final prompt = dp.promptForLocale(
      index: idx,
      languageCode: Localizations.localeOf(context).languageCode,
      isDream: isDream,
    );

    // Theme-driven gradient with a daily hue rotation: the banner always
    // belongs to the ACTIVE theme (primary → tertiary) yet every day shifts
    // the hue slightly, so consecutive days stay visually distinct without
    // ever clashing with the app palette.
    // The swing is deliberately capped at ±24°: the old `(idx * 17) % 360`
    // walked the whole color wheel, so a lavender app could get a green
    // banner — a palette clash rather than a daily variation.
    final scheme = Theme.of(context).colorScheme;
    final shift = (((idx % 5) - 2) * 12).toDouble();
    Color shiftHue(Color c, double delta) => HSLColor.fromColor(c)
        .withHue((HSLColor.fromColor(c).hue + delta) % 360)
        .toColor();
    final gradient = [
      shiftHue(scheme.primary, shift.toDouble()),
      shiftHue(scheme.tertiary, shift.toDouble()),
    ];

    return Padding(
      // Inside the list header the list already applies 16px horizontal
      // padding — only keep vertical rhythm here.
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        elevation: 6,
        shadowColor: gradient.first.withValues(alpha: 0.3),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Stack(
              children: [
                // Subtle decorative circles in the background for depth
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -15,
                  left: 30,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon tile with frosted glass + glow
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.30),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: gradient.first.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(prompt.icon, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prompt.title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontSize: 15,
                                    letterSpacing: 0.2,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              prompt.subtitle,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    height: 1.3,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      // Day counter badge — shows which prompt
                      // of the cycle we're on.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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

typedef _DailyGuidePrompt = dp.DailyGuidePrompt;

class _FavoritesBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _FavoritesBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // Inside the list header the list already applies 16px horizontal
      // padding — only keep vertical rhythm here.
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L.tr(context, 'favoritesBannerTitle'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        L.tr(context, 'favoritesBannerSubtitle'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: scheme.primary,
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

/// "Любимое дело" banner — sits ABOVE the Favorites banner in the Life tab,
/// opens the new FavoriteActivityScreen with a beautiful reading mode.
class _FavoriteActivitiesBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _FavoriteActivitiesBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // Inside the list header the list already applies 16px horizontal
      // padding — only keep vertical rhythm here.
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.secondary, scheme.tertiary],
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.spa_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L.tr(context, 'favoriteActivityBannerTitle'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 15,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          L.tr(context, 'favoriteActivityBannerSubtitle'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Colors.white,
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

class _MadeWithLove extends StatelessWidget {
  const _MadeWithLove({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_rounded,
            size: 16,
            color: scheme.primary.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 6),
          Text(
            L.tr(context, 'madeWithLove'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

/// Beautiful gradient banner for the "ВСЕ" tab — shows only note-type entries
/// (EntryType.general) count. Clickable — opens a screen with all notes.
class _AllBanner extends StatelessWidget {
  final List<JournalEntry> entries;
  final VoidCallback onTap;
  const _AllBanner({required this.entries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final notes = entries.where((e) => e.type == EntryType.general).toList();
    if (notes.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // Inside the list header the list already applies 16px horizontal
      // padding — only keep vertical rhythm here.
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.secondary, scheme.tertiary],
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L.tr(context, 'tabNotes'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 15,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${L.tr(context, 'totalEntries')}: ${notes.length}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${notes.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Colors.white,
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

/// Screen showing all notes (EntryType.general) when tapping the banner.
class _NotesListScreen extends StatefulWidget {
  final List<JournalEntry> notes;
  final StorageService storage;
  final VoidCallback onChanged;

  const _NotesListScreen({
    required this.notes,
    required this.storage,
    required this.onChanged,
  });

  @override
  State<_NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<_NotesListScreen> {
  late List<JournalEntry> _notes;

  @override
  void initState() {
    super.initState();
    _notes = List.from(widget.notes);
  }

  Future<void> _openDetail(JournalEntry entry) async {
    final changed = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            EntryDetailScreen(
              entry: entry,
              storage: widget.storage,
              heroPrefix: 'notes',
              onRestored: () {
                widget.onChanged();
                widget.storage.loadEntries().then((entries) {
                  if (mounted) {
                    setState(() {
                      _notes = entries
                          .where((e) => e.type == EntryType.general)
                          .toList();
                    });
                  }
                });
              },
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
    if (changed == true && mounted) {
      widget.onChanged();
      // Reload notes
      final entries = await widget.storage.loadEntries();
      if (mounted) {
        setState(() {
          _notes = entries.where((e) => e.type == EntryType.general).toList();
        });
      }
    }
  }

  Future<void> _togglePin(JournalEntry entry) async {
    await widget.storage.patchEntry(entry.id, {'pinned': !entry.pinned});
    widget.onChanged();
    final entries = await widget.storage.loadEntries();
    if (mounted) {
      setState(() {
        _notes = entries.where((e) => e.type == EntryType.general).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L.tr(context, 'tabNotes')),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        flexibleSpace: PremiumHeader(
          colors: AppTheme.headerColors(Theme.of(context).colorScheme),
        ),
      ),
      body: _notes.isEmpty
          ? Center(
              child: Text(
                L.tr(context, 'emptyNotes'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                widget.onChanged();
                final entries = await widget.storage.loadEntries();
                if (mounted) {
                  setState(() {
                    _notes = entries
                        .where((e) => e.type == EntryType.general)
                        .toList();
                  });
                }
              },
              child: ListView.builder(
                scrollCacheExtent: const ScrollCacheExtent.pixels(900),
                padding: const EdgeInsets.all(16),
                itemCount: _notes.length + 1,
                itemBuilder: (context, i) {
                  if (i == _notes.length) return const _MadeWithLove();
                  return _EntryCard(
                    key: ValueKey(_notes[i].id),
                    index: i,
                    entry: _notes[i],
                    heroTag: 'note-${_notes[i].id}',
                    onTap: () => _openDetail(_notes[i]),
                    onPin: () => _togglePin(_notes[i]),
                    // No entrance replay on scroll: with the default true,
                    // every card re-animated (fade+slide) each time it
                    // scrolled back into view — the "doubling" flicker.
                    animate: false,
                  );
                },
              ),
            ),
    );
  }
}

/// Keeps one built widget instance until [rev] changes.
///
/// The home feed is a few hundred widgets deep and used to rebuild on every
/// frame of the pill-bar collapse (the app bar's `preferredSize` forces a
/// screen-level rebuild). Returning the identical widget makes Flutter's
/// rebuild elision stop here, so only the bars rebuild. Inherited lookups
/// (theme, text direction, tab controller) still reach the cached subtree
/// normally — those dependencies mark their own elements dirty.
class _StableFeed extends StatefulWidget {
  final int rev;
  final WidgetBuilder builder;

  const _StableFeed({required this.rev, required this.builder});

  @override
  State<_StableFeed> createState() => _StableFeedState();
}

class _StableFeedState extends State<_StableFeed> {
  Widget? _cached;
  int? _cachedRev;

  @override
  Widget build(BuildContext context) {
    if (_cached == null || _cachedRev != widget.rev) {
      _cached = widget.builder(context);
      _cachedRev = widget.rev;
    }
    return _cached!;
  }
}

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
    final ctrl = _ctrl;
    if (ctrl == null || !widget.animate) {
      // Entrance already played (or card created after it) — render the
      // card body directly, no transition overhead.
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
                      if (widget.entry.pinned) ...[
                        Icon(
                          Icons.push_pin_rounded,
                          size: 16,
                          // Theme-aware pin (was hardcoded orange).
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 4),
                      ],
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
