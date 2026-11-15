part of 'home_screen.dart';

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
  int _pinMovementRevision = 0;
  final ValueNotifier<bool> _fabVisible = ValueNotifier(true);
  double _lastScrollOffset = 0;
  final Map<String, _EntryCardPosition> _movementPositions = {};

  List<JournalEntry> _sortNotes(Iterable<JournalEntry> entries) {
    return entries.where((e) => e.type == EntryType.general).toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
  }

  void _updateNotes(Iterable<JournalEntry> entries) {
    final notes = _sortNotes(entries);
    final oldPinned = {for (final note in _notes) note.id: note.pinned};
    final pinChanged = notes.any(
      (note) =>
          oldPinned.containsKey(note.id) && oldPinned[note.id] != note.pinned,
    );
    setState(() {
      if (pinChanged) _pinMovementRevision++;
      _notes = notes;
    });
  }

  @override
  void initState() {
    super.initState();
    _notes = _sortNotes(widget.notes);
  }

  @override
  void dispose() {
    _fabVisible.dispose();
    super.dispose();
  }

  Future<void> _reloadNotes() async {
    final entries = await widget.storage.loadEntries();
    if (mounted) _updateNotes(entries);
  }

  Future<void> _createNote() async {
    await Navigator.of(
      context,
    ).push<void>(fadeRoute(const EntryScreen(defaultType: EntryType.general)));
    if (!mounted) return;
    widget.onChanged();
    await _reloadNotes();
  }

  Future<void> _openDetail(JournalEntry entry) async {
    final changed = await Navigator.of(context).push<bool>(
      fadeRoute(
        EntryDetailScreen(
          entry: entry,
          storage: widget.storage,
          heroPrefix: 'notes',
          onRestored: () {
            widget.onChanged();
            widget.storage.loadEntries().then((entries) {
              if (mounted) {
                _updateNotes(entries);
              }
            });
          },
        ),
      ),
    );
    if (changed == true && mounted) {
      widget.onChanged();
      await _reloadNotes();
    }
  }

  Future<void> _togglePin(JournalEntry entry) async {
    await widget.storage.patchEntry(entry.id, {'pinned': !entry.pinned});
    widget.onChanged();
    final entries = await widget.storage.loadEntries();
    if (mounted) {
      _updateNotes(entries);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
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
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 44,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      L.tr(context, 'emptyNotes'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                widget.onChanged();
                final entries = await widget.storage.loadEntries();
                if (mounted) {
                  _updateNotes(entries);
                }
              },
              child: NotificationListener<ScrollUpdateNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis == Axis.vertical) {
                    _shiftEntryCardPositions(
                      _movementPositions,
                      notification.scrollDelta ?? 0,
                      keyPrefix: 'note-',
                    );
                    final offset = notification.metrics.pixels;
                    if (offset <= 0) {
                      _fabVisible.value = true;
                    } else if (notification.dragDetails != null &&
                        (offset - _lastScrollOffset).abs() >= 2) {
                      _fabVisible.value = offset < _lastScrollOffset;
                    }
                    _lastScrollOffset = offset;
                  }
                  return false;
                },
                child: ListView.builder(
                  scrollCacheExtent: const ScrollCacheExtent.pixels(900),
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes.length + 1,
                  findChildIndexCallback: (key) {
                    if (key is! ValueKey<String>) return null;
                    final index = _notes.indexWhere(
                      (note) => note.id == key.value,
                    );
                    return index < 0 ? null : index;
                  },
                  itemBuilder: (context, i) {
                    if (i == _notes.length) return const _MadeWithLove();
                    final note = _notes[i];
                    return _EntryCard(
                      key: ValueKey(note.id),
                      index: i,
                      entry: note,
                      heroTag: 'note-${note.id}',
                      movementPositions: _movementPositions,
                      onTap: () => _openDetail(note),
                      onPin: () => _togglePin(note),
                      movementRevision: _pinMovementRevision,
                      // No entrance replay on scroll; only pin moves animate.
                      animate: false,
                    );
                  },
                ),
              ),
            ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _fabVisible,
        builder: (context, visible, _) => _FadeSlideFab(
          visible: visible,
          child: _PressFab(onTap: _createNote),
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
