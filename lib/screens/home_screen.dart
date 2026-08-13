import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dream_journal/l10n/strings.dart';
import 'package:dream_journal/models/entry.dart';
import 'package:dream_journal/models/settings.dart';
import 'package:dream_journal/providers/settings_provider.dart';
import 'package:dream_journal/services/storage_service.dart';
import 'package:dream_journal/ai_overlay_state.dart';
import 'package:dream_journal/screens/entry_screen.dart';
import 'package:dream_journal/screens/entry_detail_screen.dart';
import 'package:dream_journal/screens/favorite_activity_screen.dart';
import 'package:dream_journal/screens/settings_screen.dart';
import 'package:dream_journal/screens/statistics_screen.dart';
import 'package:dream_journal/screens/favorites_screen.dart';
import 'package:dream_journal/screens/daily_guide_screen.dart';
import 'package:dream_journal/widgets/reminder_dialog.dart';
import 'package:dream_journal/widgets/animated_snack.dart';
import 'package:dream_journal/services/notification_service.dart';
import 'package:dream_journal/data/daily_prompts.dart' as dp;
import 'package:dream_journal/widgets/limited_context_menu.dart';
import 'package:dream_journal/widgets/em_dash_formatter.dart';
import 'package:dream_journal/widgets/premium_header.dart';
import 'package:dream_journal/widgets/skeleton.dart';
import 'package:dream_journal/widgets/winter_hat.dart';
import 'package:dream_journal/widgets/streak_badge.dart';

Route<T> _fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 280),
  );
}

/// True once the very first entry list has played its entrance animation.
/// Cards should only animate on the very first build of a session —
/// replaying the fade+slide on every list remount / tab build caused
/// visible jank on mid-range devices (each card spun up a controller,
/// a delayed timer and a transition while scrolling).
bool _cardEntrancePlayed = false;

class HomeScreen extends StatefulWidget {
  final VoidCallback? onRequestLock;
  final bool tulpaEnabled;

  const HomeScreen({super.key, this.onRequestLock, this.tulpaEnabled = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_onSearchFocusChanged);
    _searchFocus.dispose();
    _fabVisible.dispose();
    super.dispose();
  }

  /// Hides/shows the FAB + reminders while the user drags a list: scroll
  /// down → hide, scroll up → show. Reacts only to real user drags and
  /// ignores tiny jitter.
  bool _onScrollNotification(ScrollNotification n) {
    // VERTICAL drags only: swiping the category chips row sideways is a
    // horizontal scroll and must NOT hide the row/FAB (it used to, because
    // any axis produced a positive pixels delta).
    if (n is ScrollUpdateNotification &&
        n.dragDetails != null &&
        n.metrics.axis == Axis.vertical) {
      final delta = n.metrics.pixels - _lastScrollOffset;
      if (delta.abs() < 2) return false;
      _lastScrollOffset = n.metrics.pixels;
      if (delta > 0 && _fabVisible.value) _fabVisible.value = false;
      if (delta < 0 && !_fabVisible.value) _fabVisible.value = true;
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
      if (!mounted) return;
      setState(() {
        _entries = entries;
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
    final updated = entry.copyWith(pinned: !entry.pinned);
    await _storage.updateEntry(updated);
    await _load();
  }

  void _onReorder(List<JournalEntry> list, int oldIndex, int newIndex) {
    final id = list[oldIndex].id;
    final oldPos = _entries.indexWhere((e) => e.id == id);
    if (oldPos < 0) return;
    final item = _entries.removeAt(oldPos);
    final targetId = newIndex < list.length ? list[newIndex].id : null;
    final insertPos = targetId == null
        ? _entries.length
        : _entries.indexWhere((e) => e.id == targetId);
    _entries.insert(insertPos < 0 ? _entries.length : insertPos, item);
    _sortMode = -1;
    _storage.saveEntries(_entries);
    setState(() {});
  }

  void _openEditor() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EntryScreen())).then((_) {
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
      _fadeRoute(
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
          flexibleSpace: PremiumHeader(
            colors: [scheme.primary, scheme.secondary, scheme.tertiary],
          ),
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
                                if (!mounted) return;
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
                    // Winter beanie sitting ON the first letter of the
                    // wordmark, with a slight playful tilt.
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
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
                        Positioned(
                          left: -5,
                          top: -8,
                          child: Transform.rotate(
                            angle: -0.08,
                            child: const WinterHat(
                              width: 18,
                              height: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    StreakBadge(streak: _streak),
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
              tooltip: _searching
                  ? L.tr(context, 'closeSearch')
                  : L.tr(context, 'search'),
            ),
            IconButton(
              icon: const Icon(Icons.insights_rounded),
              tooltip: L.tr(context, 'statistics'),
              onPressed: () {
                _searchFocus.unfocus();
                Navigator.of(
                  context,
                ).push(_fadeRoute(const StatisticsScreen()));
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: L.tr(context, 'settings'),
              onPressed: () {
                _searchFocus.unfocus();
                Navigator.of(
                  context,
                ).push(_fadeRoute(const SettingsScreen())).then((_) => _load());
              },
            ),
          ],
          bottom: _SmoothTabPills(
            labels: defs.map((d) => d.$1).toList(),
            headerColor: headerBg,
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
                    Column(
                      children: [
                        // Category chips + sort live in ONE compact
                        // pill-bar (they never hide when the feed scrolls —
                        // only the "+" FAB and the reminders button do).
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                          child: _CategoryChips(
                            current: _category,
                            sortMode: _sortMode,
                            onChanged: (c) => setState(() => _category = c),
                            onSort: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _sortMode =
                                    _sortMode >= 2 ? -1 : _sortMode + 1;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: Stack(
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
                                                        _fadeRoute(
                                                          const FavoriteActivityScreen(),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  _FavoritesBanner(
                                                    onTap: () {
                                                      Navigator.of(context).push(
                                                        MaterialPageRoute(
                                                          builder: (_) =>
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
                                                      _fadeRoute(
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
                                                  entries: _filtered(d.$2),
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
                                                      _fadeRoute(
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
                                filter: ImageFilter.blur(
                                  sigmaX: 18,
                                  sigmaY: 18,
                                ),
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
                                        magnifierConfiguration:
                                            TextMagnifierConfiguration.disabled,
                                        contextMenuBuilder: (ctx, state) =>
                                            buildLimitedContextMenu(ctx, state),
                                        focusNode: _searchFocus,
                                        // Убран autofocus: поле фокусируется только при явном открытии поиска
                                        maxLength: 50,
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
                                    if (_searchQuery.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.clear_rounded),
                                        onPressed: () {
                                          setState(() => _searchQuery = '');
                                          _searchFocus.requestFocus();
                                        },
                                        tooltip: L.tr(context, 'clear'),
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
            child: Material(
              color: Theme.of(context).colorScheme.primary,
              elevation: 6,
              shadowColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.4),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _openEditor();
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  _openAiAssistant();
                },
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

  // Pill height (52) + its bottom margin (12).
  @override
  Size get preferredSize => const Size.fromHeight(64);

  const _SmoothTabPills({
    required this.labels,
    required this.headerColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    final count = labels.length;
    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
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
              return Stack(
                children: [
                  // The pill follows the animation continuously: glides with
                  // swipes, springs between tabs on taps.
                  Positioned(
                    left: value * segW,
                    width: segW,
                    top: 0,
                    bottom: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
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
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onTap?.call(i);
                              // Animate from inside the controller scope:
                              // calling DefaultTabController.of() from the
                              // home screen's own context (above the
                              // DefaultTabController) would silently hit the
                              // fallback controller and never switch tabs.
                              controller.animateTo(i);
                            },
                            borderRadius: BorderRadius.circular(26),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                style: TextStyle(
                                  color: i == index
                                      ? headerColor
                                      : Colors.white.withValues(alpha: 0.75),
                                  fontWeight: i == index
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
                                ),
                                child: Text(labels[i]),
                              ),
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
    );
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
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final idx = cats.indexOf(current);
                return Stack(
                  children: [
                    // Sliding highlight: one rounded fill that glides
                    // across the segments (easeOutCubic, 360ms) — much
                    // smoother than fading each segment's fill in place.
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment(
                        idx == 0
                            ? -1.0
                            : idx == cats.length - 1
                            ? 1.0
                            : -1.0 + 2 * idx / (cats.length - 1),
                        0,
                      ),
                      widthFactor: 1 / cats.length,
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) =>
                  RotationTransition(
                    turns: Tween(begin: 0.75, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
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
class _SearchToggleButton extends StatelessWidget {
  final bool isSearching;
  final VoidCallback onTap;
  final String tooltip;

  const _SearchToggleButton({
    required this.isSearching,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(isSearching ? Icons.close_rounded : Icons.search_rounded),
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
      // Smooth ease-in-out glide + fade + gentle scale — the control
      // melts away instead of snapping.
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubic,
      offset: visible ? Offset.zero : const Offset(0, 1.6),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
        scale: visible ? 1.0 : 0.65,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOut,
          opacity: visible ? 1.0 : 0.0,
          child: IgnorePointer(ignoring: !visible, child: child),
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
    final firstId = entries.isNotEmpty ? entries.first.id : '';
    final lastTs = entries.isNotEmpty
        ? entries.last.updatedAt.millisecondsSinceEpoch
        : 0;
    final orderKey = entries.isNotEmpty
        ? entries.take(5).map((e) => e.id.substring(0, 4)).join(',')
        : '';
    final signature = '${entries.length}:$firstId:$lastTs:$orderKey';
    // The entrance animation plays only for the very first list built this
    // session; later lists (tab switches, remounts, refreshes) render
    // statically — replaying it caused visible jank on mid-range devices.
    final animateEntrance = !_cardEntrancePlayed;
    if (entries.isNotEmpty && animateEntrance) _cardEntrancePlayed = true;

    if (entries.isEmpty) {
      // No AnimatedSwitcher here: during a category cross-fade the OLD
      // (taller) and NEW (shorter) lists coexist and the section keeps the
      // taller height — the practice-of-the-day banner appeared to "grow"
      // while switching to an empty category like Random. A plain swap is
      // instant and stable.
      return RepaintBoundary(
        child: RefreshIndicator(
          key: ValueKey('empty:$signature'),
          onRefresh: onRefresh,
          child: ListView(
          // Same horizontal padding as the populated list, so the
          // practice-of-the-day header keeps the EXACT same width (and
          // height) whether the category has entries or not. Without it
          // the header rendered full-bleed (504px vs 472px) and its text
          // re-wrapped — the banner visually "grew" on empty categories.
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          children: [
            if (header != null) header!,
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
    }

    // Populated list: also NO cross-fade — a category switch swaps the
    // list content instantly, so the practice banner never "grows".
    // Wrap with RepaintBoundary to isolate list repaints from the rest of the UI
    return RepaintBoundary(
      child: RefreshIndicator(
        key: ValueKey(signature),
        onRefresh: onRefresh,
        child: ReorderableListView.builder(
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

  // A rotating palette of gradient pairs — each day the banner picks the
  // next palette so consecutive days never look the same.
  static const _palettes = <List<Color>>[
    [Color(0xFF7B61FF), Color(0xFF00C6FF)], // purple-blue
    [Color(0xFF6366F1), Color(0xFFEC4899)], // indigo-pink
    [Color(0xFF14B8A6), Color(0xFF3B82F6)], // teal-blue
    [Color(0xFFF59E0B), Color(0xFFEF4444)], // amber-red
    [Color(0xFF8B5CF6), Color(0xFF06B6D4)], // violet-cyan
    [Color(0xFFEC4899), Color(0xFFF97316)], // pink-orange
    [Color(0xFF10B981), Color(0xFF6366F1)], // emerald-indigo
    [Color(0xFFEF4444), Color(0xFFFBBF24)], // red-yellow
    [Color(0xFF0EA5E9), Color(0xFFA855F7)], // sky-purple
    [Color(0xFFD946EF), Color(0xFF06B6D4)], // fuchsia-cyan
    [Color(0xFF84CC16), Color(0xFF14B8A6)], // lime-teal
    [Color(0xFFFB923C), Color(0xFFE11D48)], // orange-rose
  ];

  static const _tulpaPalettes = <List<Color>>[
    [Color(0xFFFF6C87), Color(0xFFFFA84B)], // rose-orange
    [Color(0xFFEC4899), Color(0xFFF97316)], // pink-orange
    [Color(0xFFD946EF), Color(0xFFFB923C)], // fuchsia-peach
    [Color(0xFF8B5CF6), Color(0xFFFBBF24)], // violet-gold
    [Color(0xFF06B6D4), Color(0xFFA855F7)], // cyan-purple
    [Color(0xFFF43F5E), Color(0xFFFBBF24)], // rose-gold
    [Color(0xFFEF4444), Color(0xFFEC4899)], // red-pink
    [Color(0xFFFB7185), Color(0xFFFDE68A)], // soft-pink-cream
  ];

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
    // ever clashing with the app palette. The fixed palettes remain only as
    // a soft accent for the icon glow.
    final scheme = Theme.of(context).colorScheme;
    final palettes = isDream ? _palettes : _tulpaPalettes;
    final accent = palettes[idx % palettes.length];
    final shift = (idx * 17) % 360;
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
                              color: accent.first.withValues(alpha: 0.35),
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
    final updated = entry.copyWith(pinned: !entry.pinned);
    await widget.storage.updateEntry(updated);
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
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
            Theme.of(context).colorScheme.tertiary,
          ],
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
      duration: const Duration(milliseconds: 300),
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
    final delay = Duration(milliseconds: 10 + widget.index.clamp(0, 12) * 30);
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
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _pressed
              ? scheme.primary.withValues(alpha: 0.55)
              : Colors.transparent,
          width: 1.6,
        ),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        // Elevation + soft shadow give the cards a volumetric "lift" that
        // reads well on every theme (the old flat surfaceContainerLow fill
        // plus the colored side accent bar clashed with custom themes).
        // Kept low (2) on purpose: every blurred shadow in a scrollable
        // list costs real GPU fill on low-end devices (Redmi), and the
        // border + gradient already carry the depth.
        elevation: 2,
        color: Colors.transparent,
        shadowColor: scheme.shadow.withValues(alpha: 0.28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onPin,
          onHighlightChanged: (v) {
            if (mounted && v != _pressed) {
              setState(() => _pressed = v);
            }
          },
          borderRadius: BorderRadius.circular(24),
          // Subtle top-left → bottom-right gradient adds depth without a
          // colored side bar (which didn't fit the custom themes).
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surfaceContainerLow,
                  scheme.surfaceContainerHighest.withValues(alpha: 0.75),
                ],
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
                                  ? Colors.amber.withValues(alpha: 0.2)
                                  : Colors.blueGrey.withValues(alpha: 0.15),
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
                                color: widget.entry.isLucid!
                                    ? Colors.amber.shade800
                                    : Colors.blueGrey,
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
  return switch (c) {
    EntryCategory.good => Colors.green,
    EntryCategory.bad => Colors.redAccent,
    EntryCategory.random => Colors.blueAccent,
    EntryCategory.none => Colors.grey,
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
