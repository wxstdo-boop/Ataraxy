import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';
import 'package:dream_journal/l10n/strings.dart';
import 'package:dream_journal/models/dream_signs.dart';
import 'package:dream_journal/models/entry.dart';
import 'package:dream_journal/screens/entry_screen.dart';
import 'package:dream_journal/services/storage_service.dart';
import 'package:dream_journal/widgets/animated_snack.dart';
import 'package:dream_journal/widgets/em_dash_formatter.dart';
import 'package:dream_journal/widgets/premium_header.dart';

class EntryDetailScreen extends StatefulWidget {
  final JournalEntry entry;
  final StorageService storage;

  /// Namespace of the home tab the entry was opened from ("dream", "life",
  /// "tulpa", "all", "notes") so the shared-element tag is unique even when
  /// the same entry is visible in two tabs at once.
  final String heroPrefix;

  /// Called after the user taps "Вернуть" on the delete-undo snackbar, so
  /// the caller (home screen) can reload its list.
  final VoidCallback? onRestored;

  const EntryDetailScreen({
    super.key,
    required this.entry,
    required this.storage,
    this.heroPrefix = '',
    this.onRestored,
  });

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  // Local copy of the entry: editing replaces it in place so the preview
  // shows the updated content while the user is still on this screen.
  late JournalEntry _entry = widget.entry;

  // Set when the editor returned a saved entry — the pop must signal the
  // home feed to reload.
  bool _edited = false;

  JournalEntry get entry => _entry;

  /// Matches the hero tag used on the home list card ("entry-title-"
  /// + tab prefix + entry id) so the shared-element flight connects.
  String get heroTag => 'entry-title-$heroPrefix-${entry.id}';

  String get heroPrefix => widget.heroPrefix;

  Color _typeColor(EntryType type) {
    return switch (type) {
      EntryType.dream => Colors.purpleAccent,
      EntryType.life => Colors.teal,
      EntryType.general => Colors.deepOrangeAccent,
      EntryType.tulpa => Colors.indigoAccent,
    };
  }

  Future<void> _openEditor() async {
    final result = await Navigator.of(context).push<JournalEntry>(
      MaterialPageRoute(
        builder: (_) => EntryScreen(entry: widget.entry),
      ),
    );
    if (result != null && mounted) {
      // Editor returns the SAVED entry: swap it into the preview in place,
      // so the user stays on the (fresh) preview instead of being kicked
      // back to the feed. Mark edited so popping reloads the feed.
      setState(() {
        _entry = result;
        _edited = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _typeColor(entry.type);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mounted) {
          // After an edit, signal the feed to reload; otherwise a plain
          // back leaves the list as-is.
          Navigator.of(context).pop(_edited);
        }
      },
      child: Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
        title: Text(L.tr(context, entry.type.labelKey)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: _openEditor,
          ),
          IconButton(
            icon: Icon(
              entry.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: entry.pinned ? Colors.orange : null,
            ),
            onPressed: () async {
              final updated = entry.copyWith(pinned: !entry.pinned);
              await widget.storage.updateEntry(updated);
              if (context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
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
                      child: Text(L.tr(context, 'delete')),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                final deleted = entry;
                await widget.storage.deleteEntry(entry.id);
                if (context.mounted) {
                  AnimatedSnack.show(
                    context,
                    L.tr(context, 'entryDeleted'),
                    type: SnackType.info,
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: L.tr(context, 'restore'),
                      onPressed: () async {
                        await widget.storage.restoreEntry(deleted);
                        widget.onRestored?.call();
                      },
                    ),
                  );
                  Navigator.of(context).pop(true);
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shared-element flight from the list card: the title morphs
              // from the card into this heading.
              Hero(
                tag: 'entry-title-$heroTag',
                child: Material(
                  type: MaterialType.transparency,
                  child: Text(
                    entry.title.isEmpty
                        ? L.tr(context, 'withoutTitle')
                        : entry.title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            if (entry.type == EntryType.dream && entry.isLucid != null) ...[
              const SizedBox(height: 8),
              Chip(
                label: Text(
                  entry.isLucid!
                      ? L.tr(context, 'lucidBadge')
                      : L.tr(context, 'normalBadge'),
                ),
                avatar: Icon(
                  entry.isLucid!
                      ? Icons.auto_awesome_rounded
                      : Icons.nights_stay_rounded,
                  size: 16,
                ),
              ),
            ],
            if (entry.category != EntryCategory.none) ...[
              const SizedBox(height: 8),
              Chip(
                label: Text(L.tr(context, entry.category.labelKey)),
                avatar: const Icon(Icons.bookmark_rounded, size: 16),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 16, color: scheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Text(
                  DateFormat('d MMMM y, HH:mm',
                          Localizations.localeOf(context).languageCode)
                      .format(entry.createdAt),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                ),
                const Spacer(),
                Row(
                  children: List.generate(5, (i) {
                    final active = i < entry.mood;
                    return Icon(
                      active
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 18,
                      color:
                          active ? color : scheme.onSurface.withValues(alpha: 0.25),
                    );
                  }),
                ),
              ],
            ),
            _dreamSigns(context, entry, color),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(18),
              ),
              child: entry.content.isEmpty
                      ? Text(
                          L.tr(context, 'noText'),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                        )
                      : MarkdownBody(
                          data: emDash(entry.content),
                          selectable: true,
                          // Keep the user's own line breaks: a single \n
                          // renders as a real break, not a collapsed space.
                          softLineBreak: true,
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
                            code: TextStyle(
                              backgroundColor: scheme.surfaceContainerHighest,
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            blockquoteDecoration: BoxDecoration(
                              border: Border(left: BorderSide(color: scheme.primary, width: 3)),
                            ),
                            listBullet: TextStyle(color: scheme.primary),
                          ),
                        ),
            ),
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entry.tags
                    .map((t) => Chip(label: Text('#$t')))
                    .toList(),
              ),
            ],
            if (entry.type == EntryType.tulpa &&
                entry.forcingDuration != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_bottom_rounded,
                        size: 20, color: color),
                    const SizedBox(width: 10),
                    Text(
                      '${L.tr(context, 'forcingDuration')}: '
                      '${_formatDuration(context, entry.forcingDuration!)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            if (entry.type == EntryType.life &&
                entry.waterLiters != null) ...[
              const SizedBox(height: 16),
              _InfoTile(
                icon: Icons.water_drop_rounded,
                label: '${L.tr(context, 'water')}: ${entry.waterLiters}',
                color: color,
              ),
            ],
            if (entry.type == EntryType.life &&
                (entry.fastingStart != null || entry.fastingEnd != null)) ...[
              const SizedBox(height: 12),
              _InfoTile(
                icon: Icons.timer_rounded,
                label:
                    '${L.tr(context, 'fastingWindow')}: '
                    '${entry.fastingStart ?? '--:--'} — ${entry.fastingEnd ?? '--:--'}',
                color: color,
              ),
            ],
            if (entry.type == EntryType.life &&
                (entry.pomodoroStart != null || entry.pomodoroEnd != null)) ...[
              const SizedBox(height: 12),
              _InfoTile(
                icon: Icons.bolt_rounded,
                label:
                    '${L.tr(context, 'pomodoro')}: '
                    '${entry.pomodoroStart ?? '--:--'} — ${entry.pomodoroEnd ?? '--:--'}',
                color: color,
              ),
            ],
            if (entry.type == EntryType.life &&
                entry.hrtTime != null) ...[
              const SizedBox(height: 12),
              _InfoTile(
                icon: Icons.medication_rounded,
                label:
                    '${L.tr(context, 'hrtTime')}: ${entry.hrtTime}'
                    '${entry.hrtDosage != null ? ' — ${entry.hrtDosage}' : ''}',
                color: color,
              ),
            ],
            if (entry.type == EntryType.life &&
                entry.waterLiters != null) ...[
              // будущие трекеры
            ],
          ],
        ),
      ),
      ),
    );
  }

  String _formatDuration(BuildContext context, Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') return '${h > 0 ? '$h ч ' : ''}$m мин';
    return '${h > 0 ? '$h h ' : ''}$m min';
  }

  Widget _dreamSigns(BuildContext context, JournalEntry entry, Color color) {
    if (entry.type != EntryType.dream || entry.dreamSigns.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: entry.dreamSigns.map((s) {
          return Chip(
            avatar: Icon(DreamSigns.iconOf(s), size: 16, color: color),
            label: Text(DreamSigns.label(context, s)),
            backgroundColor: color.withValues(alpha: 0.12),
            labelStyle: TextStyle(color: color),
          );
        }).toList(),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
