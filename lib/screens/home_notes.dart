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
