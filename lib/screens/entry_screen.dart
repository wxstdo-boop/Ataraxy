import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:ataraxy/l10n/strings.dart';
import 'package:ataraxy/widgets/animated_field_counter.dart';
import 'package:ataraxy/widgets/app_route.dart';
import 'package:ataraxy/models/dream_signs.dart';
import 'package:ataraxy/models/entry.dart';
import 'package:ataraxy/widgets/pressable_icon_button.dart';
import 'package:ataraxy/providers/settings_provider.dart';
import 'package:ataraxy/screens/entry_detail_screen.dart';
import 'package:ataraxy/screens/pomodoro_screen.dart';
import 'package:ataraxy/services/storage_service.dart';
import 'package:ataraxy/theme/app_theme.dart';
import 'package:ataraxy/widgets/limited_context_menu.dart';
import 'package:ataraxy/widgets/animated_snack.dart';
import 'package:ataraxy/widgets/animated_chip.dart';
import 'package:ataraxy/widgets/em_dash_formatter.dart';
import 'package:ataraxy/widgets/premium_header.dart';
import 'package:ataraxy/widgets/themed_time_picker.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class EntryScreen extends StatefulWidget {
  final JournalEntry? entry;
  final EntryCategory defaultCategory;
  final EntryType? defaultType;

  const EntryScreen({
    super.key,
    this.entry,
    this.defaultCategory = EntryCategory.none,
    this.defaultType,
  });

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> with WidgetsBindingObserver {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();
  final _signController = TextEditingController();
  final _waterController = TextEditingController();
  final _hrtDosageController = TextEditingController();
  final StorageService _storage = StorageService();
  SpeechToText? _speech;

  late EntryType _type;
  int _mood = 3;
  List<String> _tags = [];
  bool? _isLucid;
  Duration? _forcingDuration;
  List<String> _dreamSigns = [];
  EntryCategory _category = EntryCategory.none;
  String? _fastingStart;
  String? _fastingEnd;
  String? _pomodoroStart;
  String? _pomodoroEnd;
  String? _hrtTime;
  late DateTime _createdAt;
  // Frozen sort key. Used to be `DateTime.now()` inside `_buildEntry()`, so
  // every autosave tick of a NEW entry stamped a fresh `updatedAt` and the
  // half-written note kept jumping to the top of the feed while typing.
  late DateTime _updatedAt;
  late final String _id;
  bool _listening = false;
  bool _pinned = false;
  bool _autosave = false;
  // Live markdown preview toggle — when on, the body renders as Markdown
  // instead of the raw editor, so **stars** never stare back at you.
  bool _previewMode = false;
  Timer? _autosaveTimer;
  String _lastSig = '';
  // Last title/content seen by the autosave tick — used for the cheap
  // change check before building the (potentially huge) entry.
  String _lastSigTitle = '';
  String _lastSigContent = '';
  // Guards against overlapping autosave runs: the periodic timer fires
  // every second regardless of whether the previous (async) save has
  // finished. With a huge entry the old code let saves pile up, each one
  // re-reading and re-writing the whole list on the UI isolate — that
  // CPU/memory storm is what got the app killed mid-typing.
  bool _autosaveRunning = false;
  
  // Guards against overlapping manual save taps: prevents double-save race
  // conditions where rapid taps could overwrite or lose data.
  bool _saving = false;

  // Serializes ALL storage writes (manual save, autosave tick, dispose
  // save) through a single FIFO queue. Hive's box.put is async and NOT
  // ordered: a stale autosave that started earlier can finish its write
  // AFTER a newer manual save and silently revert the entry to older text
  // ("some of what I typed got erased"). Because every write is chained,
  // the most recently queued write is always the LAST to hit the disk, so
  // the freshest text wins.
  Future<void> _writeQueue = Future.value();

  /// Signature of the entry that last reached the disk. Used only to skip a
  /// redundant flush — so it must be refreshed on SUCCESS, never when the
  /// write is merely queued: a failed write that marked itself as done made
  /// every later flush of the same text a no-op, and those words were gone.
  String _lastWrittenSig = '';

  /// Re-entrancy latch for the exit-flush: the back gesture can fire several
  /// pop attempts while the final write is still in flight.
  bool _closing = false;

  Future<void> _enqueueWrite(JournalEntry entry) {
    final sig = _signature(entry);
    final next = _writeQueue.then((_) async {
      await _storage.addEntry(entry);
      // Only now, with the bytes on disk, is this text considered saved.
      _lastWrittenSig = sig;
    });
    // Keep the chain alive even if one write fails, and don't unhandled-zone
    // a storage error here (that used to kill the app on release builds).
    _writeQueue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  /// Writes the editors' current content and AWAITS the disk. This is the
  /// single safety net behind "I typed a wall of text, left, and it was gone":
  /// `autosave` in Settings only controls the 1s tick while typing — it used
  /// to gate the save-on-exit as well, so with the (default) off setting any
  /// exit that wasn't the checkmark button discarded everything.
  ///
  /// Skips a completely empty note (so opening the editor and backing out
  /// can't leave ghost entries) and a note identical to the last write.
  /// Returns the entry as it now stands on disk, or null when there was
  /// nothing to save — the caller needs it to hand the fresh entry back to
  /// the preview screen.
  Future<({JournalEntry? entry, bool ok})> _flushUnsaved() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) return (entry: null, ok: true);
    final entry = _buildEntry();
    if (_signature(entry) == _lastWrittenSig) return (entry: entry, ok: true);
    try {
      await _enqueueWrite(entry);
      return (entry: entry, ok: true);
    } catch (e) {
      debugPrint('[Save] flush error: $e');
      return (entry: null, ok: false);
    }
  }

  /// System back / the AppBar arrow / a swipe: flush first, close only after
  /// the write is on disk, so the feed the previous screen reloads already
  /// contains the note.
  Future<void> _exitWithSave() async {
    if (_closing) return;
    _closing = true;
    final result = await _flushUnsaved();
    _closing = false;
    if (!mounted) return;
    if (!result.ok) {
      AnimatedSnack.show(
        context,
        L.tr(context, 'saveFailed'),
        type: SnackType.error,
      );
    }
    Navigator.of(context).pop(result.entry);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // MIUI is aggressive about killing backgrounded apps; the last second of
    // typing must not live only in memory.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _flushUnsaved();
    }
  }

  void _startAutosaveTimer() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _autosaveTick(),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _type = widget.defaultType ?? EntryType.life;
    final e = widget.entry;
    if (e != null) {
      _applyEntry(e);
      // The caller hands us a snapshot taken when its own screen was built.
      // If a later autosave already moved the stored copy forward, seeding
      // from the snapshot and saving would push the older body back over the
      // user's newest words — the reported "words disappear" bug. Adopt the
      // newer copy while the field still shows exactly what we were given.
      unawaited(_adoptNewerCopy(e));
    } else {
      _createdAt = DateTime.now();
      _updatedAt = _createdAt;
      // Use microseconds for more unique IDs to avoid collisions
      _id = _createdAt.microsecondsSinceEpoch.toString();
      _category = widget.defaultCategory;
    }
    // НЕ читаем autosave в initState — context ещё не привязан к SettingsProvider!
    // Чтение произойдёт в didChangeDependencies.
  }

  void _applyEntry(JournalEntry e) {
    _updatedAt = e.updatedAt;
    _titleController.text = e.title;
    _contentController.text = e.content;
    _type = e.type;
    _mood = e.mood;
    _tags = List.from(e.tags);
    _isLucid = e.isLucid;
    _forcingDuration = e.forcingDuration;
    _dreamSigns = List.from(e.dreamSigns);
    _category = e.category;
    _fastingStart = e.fastingStart;
    _fastingEnd = e.fastingEnd;
    _pomodoroStart = e.pomodoroStart;
    _pomodoroEnd = e.pomodoroEnd;
    _hrtTime = e.hrtTime;
    _hrtDosageController.text = e.hrtDosage ?? '';
    _createdAt = e.createdAt;
    _id = e.id;
    _pinned = e.pinned;
    _waterController.text = e.waterLiters?.toString() ?? '';
  }

  Future<void> _adoptNewerCopy(JournalEntry from) async {
    final JournalEntry? disk;
    try {
      disk = await _storage.readEntry(from.id);
    } catch (e) {
      debugPrint('[Editor] readEntry failed: $e');
      return;
    }
    if (disk == null || !mounted) return;
    if (!disk.updatedAt.isAfter(from.updatedAt)) return;
    // Anything already written by this session outranks the stored copy.
    if (_lastWrittenSig.isNotEmpty) return;
    // The user has typed: their keystrokes are the freshest data.
    if (_titleController.text != from.title ||
        _contentController.text != from.content) {
      return;
    }
    _applyEntry(disk);
    _lastSig = '';
    _lastSigTitle = '';
    _lastSigContent = '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Читаем autosave здесь — контекст уже привязан к SettingsProvider
    _autosave = SettingsProvider.of(context).settings.autosave;
    if (_autosave) {
      _startAutosaveTimer();
    }
  }

  @override
  void didUpdateWidget(EntryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Если тип записи изменился (например, переключили с Dreams на Life),
    // сбрасываем lastSig чтобы новое сохранение точно записалось
    if (oldWidget.entry != widget.entry) {
      _lastSig = '';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    // Last-resort net for a route torn down without going through
    // `_exitWithSave` (a programmatic pop from elsewhere in the tree). The
    // normal exit path already awaited its write by the time we get here, and
    // `_flushUnsaved` dedupes on the signature, so this is usually a no-op.
    unawaited(_flushUnsaved());
    if (_listening) _speech?.stop();
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _signController.dispose();
    _waterController.dispose();
    _hrtDosageController.dispose();
    super.dispose();
  }

  // Covers every field that lives outside the two text editors. The old
  // signature stopped at the fasting timers, so flipping only the pin or the
  // lucidity switch never looked like a change and never got written.
  String _signature(JournalEntry e) =>
      '${e.type.name}|${e.title}|${e.content}|${e.mood}|${e.tags.join(',')}|'
      '${e.category.name}|${e.isLucid}|${e.dreamSigns.join(',')}|'
      '${e.forcingDuration}|${e.waterLiters}|${e.fastingStart}|'
      '${e.fastingEnd}|${e.pomodoroStart}|${e.pomodoroEnd}|${e.hrtTime}|'
      '${e.hrtDosage}|${e.pinned}';

  JournalEntry _buildEntry() {
    return JournalEntry(
      id: _id,
      type: _type,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      createdAt: _createdAt,
      // Editing must NOT bump the sort key: the home feed orders by
      // updatedAt, so setting it to now on every save (incl. autosave) made
      // the entry jump to the top mid-edit. Keep the original timestamp
      // when editing an existing entry — it stays exactly where it was.
      updatedAt: _updatedAt,
      mood: _mood,
      tags: _tags,
      isLucid: _type == EntryType.dream ? _isLucid : null,
      forcingDuration: _type == EntryType.tulpa ? _forcingDuration : null,
      dreamSigns: _type == EntryType.dream ? _dreamSigns : const [],
      category: _category,
      waterLiters: _type == EntryType.life
          ? double.tryParse(_waterController.text.replaceAll(',', '.'))
          : null,
      fastingStart: _type == EntryType.life ? _fastingStart : null,
      fastingEnd: _type == EntryType.life ? _fastingEnd : null,
      pomodoroStart: _type == EntryType.life ? _pomodoroStart : null,
      pomodoroEnd: _type == EntryType.life ? _pomodoroEnd : null,
      hrtTime: _type == EntryType.life ? _hrtTime : null,
      hrtDosage: _type == EntryType.life
          ? _hrtDosageController.text.trim().isEmpty
              ? null
              : _hrtDosageController.text.trim()
          : null,
      pinned: _pinned,
    );
  }

  Future<void> _autosaveTick() async {
    if (!mounted || _autosaveRunning) return;
    _autosaveRunning = true;
    try {
      // Cheap short-circuit BEFORE building the entry: if the title and
      // body text are untouched since the last save, skip the (potentially
      // 800k-char) entry build + signature entirely. Mood/tags/type still
      // go through the full signature check below.
      final title = _titleController.text;
      final content = _contentController.text;
      if (title == _lastSigTitle && content == _lastSigContent) return;
      try {
        await _autosaveWrite();
      } catch (e) {
        // A failed autosave must NEVER escape the zone: an unhandled async
        // error in release mode kills the app and the user's typed text is
        // gone with it ("the app reloads and my entry is erased").
        debugPrint('[Autosave] tick error: $e');
        // Forget the "already stored" markers so the next tick retries this
        // exact text instead of short-circuiting on it.
        _lastSig = '';
        _lastSigTitle = '';
        _lastSigContent = '';
      }
    } finally {
      _autosaveRunning = false;
    }
  }

  /// Builds and stores the current entry for the autosave timer. The write
  /// itself is isolated so a storage failure can't take the editor down.
  Future<void> _autosaveWrite() async {
    // Never clobber a manual save that's in flight: the user has just hit
    // the checkmark, so their freshest text must be the last one on disk.
    if (_saving) return;
    final entry = _buildEntry();
    // Сохраняем даже пустые записи — пользователь мог начать вводить текст
    final sig = _signature(entry);
    if (sig == _lastSig && entry.title.isEmpty && entry.content.isEmpty) {
      return;
    }
    await _enqueueWrite(entry);
    // Marked after the write: a tick that threw must stay retryable, or the
    // text it failed on is silently never stored again.
    _lastSig = sig;
    _lastSigTitle = entry.title;
    _lastSigContent = entry.content;
  }

  void _addTag() {
    final value = _tagController.text.trim();
    if (value.isEmpty || _tags.contains(value)) return;
    if (value.length > 10) {
      AnimatedSnack.show(
        context,
        L.tr(context, 'tagTooLong'),
        type: SnackType.warning,
      );
      return;
    }
    if (_tags.length >= 3) {
      AnimatedSnack.show(
        context,
        L.tr(context, 'tagsLimit'),
        type: SnackType.warning,
      );
      return;
    }
    setState(() {
      _tags.add(value);
      _tagController.clear();
    });
  }

  void _addSign() {
    final value = _signController.text.trim();
    if (value.isEmpty) return;
    if (value.length > 10) {
      AnimatedSnack.show(
        context,
        L.tr(context, 'tagTooLong'),
        type: SnackType.warning,
      );
      return;
    }
    if (!_dreamSigns.contains(value)) {
      setState(() {
        _dreamSigns.add(value);
        _signController.clear();
      });
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') return '${h > 0 ? '$h ч ' : ''}$m мин';
    return '${h > 0 ? '$h h ' : ''}$m min';
  }

  Future<void> _pickForcing() async {
    final initial = _forcingDuration != null
        ? TimeOfDay(
            hour: _forcingDuration!.inHours,
            minute: _forcingDuration!.inMinutes.remainder(60),
          )
        : const TimeOfDay(hour: 0, minute: 0);
    final picked = await showThemedTimePicker(
      context,
      initialTime: initial,
      helpText: L.tr(context, 'forcingDuration'),
    );
    if (picked != null && context.mounted) {
      setState(() => _forcingDuration = Duration(
        hours: picked.hour,
        minutes: picked.minute,
      ));
    }
  }

  Future<void> _pickTimeField(String? current, ValueChanged<String> onPicked,
      BuildContext context) async {
    final initial = current == null
        ? const TimeOfDay(hour: 12, minute: 0)
        : _parseTime(current);
    final picked = await showThemedTimePicker(context, initialTime: initial);
    if (picked != null && context.mounted) {
      onPicked(_fmt(picked));
    }
  }

  TimeOfDay _parseTime(String v) {
    final parts = v.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatDateTime(DateTime dt) {
    final code = Localizations.localeOf(context).languageCode;
    final date = DateFormat('d MMM y', code).format(dt);
    final time = DateFormat('HH:mm').format(dt);
    return '$date, $time';
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _createdAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showThemedTimePicker(
      context,
      initialTime: TimeOfDay.fromDateTime(_createdAt),
    );
    if (time == null || !mounted) return;
    setState(() => _createdAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ));
  }

  Future<void> _toggleVoice() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        AnimatedSnack.show(
          context,
          L.tr(context, 'voiceUnavailable'),
          type: SnackType.warning,
        );
      }
      return;
    }

    _speech ??= SpeechToText();
    if (_listening) {
      await _speech!.stop();
      setState(() => _listening = false);
      return;
    }
    bool available;
    try {
      available = await _speech!.initialize(
        onError: (err) => debugPrint('[Voice] init error: $err'),
        // If the engine stops for any reason (interrupted, killed, app
        // backgrounded, long silence), release the UI state so the button
        // never hangs in "Слушаю…".
        onStatus: (status) {
          debugPrint('[Voice] status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted && _listening) {
              setState(() => _listening = false);
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[Voice] init exception: $e');
      available = false;
    }
    if (!available) {
      if (mounted) {
        AnimatedSnack.show(
          context,
          L.tr(context, 'voiceUnavailable'),
          type: SnackType.warning,
        );
      }
      return;
    }
    // New dictation session: subsequent chunks are appended AFTER the
    // current text, and partial results replace only the tail they own.
    _voiceInsertPos = _contentController.text.length;
    setState(() => _listening = true);
    if (!mounted) return;

    // Robust locale selection
    final loc = Localizations.localeOf(context);
    final localeId = loc.countryCode != null
        ? '${loc.languageCode}_${loc.countryCode}'
        : (loc.languageCode == 'ru' ? 'ru_RU' : 'en_US');

    String effectiveLocale;
    try {
      final systemLocale = await _speech!.systemLocale();
      final locales = await _speech!.locales();
      debugPrint('[Voice] Available locales: $locales');
      debugPrint('[Voice] System locale: $systemLocale, app locale: $localeId');

      final exactMatch = locales
          .where((l) => l.localeId == localeId)
          .toList();
      if (exactMatch.isNotEmpty) {
        effectiveLocale = localeId;
      } else {
        final langMatch = locales
            .where((l) => l.localeId.startsWith(loc.languageCode))
            .toList();
        if (langMatch.isNotEmpty) {
          effectiveLocale = langMatch.first.localeId;
        } else if (systemLocale != null) {
          effectiveLocale = systemLocale.localeId;
        } else {
          effectiveLocale = locales.isNotEmpty
              ? locales.first.localeId
              : 'ru_RU';
        }
      }
    } catch (e) {
      debugPrint('[Voice] locale detection error: $e');
      effectiveLocale = loc.languageCode == 'ru' ? 'ru_RU' : 'en_US';
    }
    debugPrint('[Voice] Using locale: $effectiveLocale');

    try {
      await _speech!.listen(
        // Long listen window + generous pause so dictation does NOT stop
        // after 3s of silence (the old default cut entries off after a few
        // words); the user ends the session via the mic button or after a
        // real long pause. dictation mode is the most compatible across
        // Android skins (deviceDefault breaks on several Xiaomi/Redmi
        // builds and silently never produces words).
        listenOptions: SpeechListenOptions(
          localeId: effectiveLocale,
          listenMode: ListenMode.dictation,
          partialResults: true,
          listenFor: const Duration(minutes: 10),
          pauseFor: const Duration(seconds: 10),
        ),
        onResult: (r) => _onVoiceResult(r, effectiveLocale),
      );
    } catch (e) {
      debugPrint('[Voice] listen error: $e');
      if (mounted) {
        setState(() => _listening = false);
        AnimatedSnack.show(
          context,
          L.tr(context, 'voiceUnavailable'),
          type: SnackType.warning,
        );
      }
    }
  }

  // Where the next dictation chunk should be inserted. Partial results
  // REPLACE everything after this position (instead of appending again and
  // again), so the same words never get duplicated while the engine is
  // refining its transcription.
  int _voiceInsertPos = 0;

  void _onVoiceResult(SpeechRecognitionResult r, String localeId) {
    if (!mounted) return;
    final words = r.recognizedWords.trim();
    if (words.isEmpty) return;
    final cur = _contentController.text;
    // Keep everything before the insert position, replace the tail with the
    // latest transcription. For partial results this is idempotent; for a
    // final result the tail is the same words, just committed.
    final head =
        cur.length <= _voiceInsertPos ? cur : cur.substring(0, _voiceInsertPos);
    final newText = head.isEmpty ? words : '$head $words';
    setState(() {
      _contentController.text = newText;
      _contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );
    });
    if (r.finalResult) {
      _voiceInsertPos = newText.length;
      if (_autosave) {
        _autosaveTick();
      }
      // Restart recognition when the buffer approaches its limit.
      final wordCount = newText
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      if (wordCount >= 1500) {
        _restartVoice(localeId);
      }
    }
  }

  Future<void> _restartVoice(String localeId) async {
    try {
      await _speech?.stop();
      if (!mounted || !_listening) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted || !_listening) return;
      await _speech!.listen(
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenMode: ListenMode.deviceDefault,
          partialResults: true,
          listenFor: const Duration(minutes: 10),
          pauseFor: const Duration(seconds: 10),
        ),
        onResult: (r) => _onVoiceResult(r, localeId),
      );
    } catch (e) {
      debugPrint('[Voice] restart error: $e');
    }
  }

  Future<void> _save() async {
    // Prevent overlapping saves from rapid taps
    if (_saving) return;
    _saving = true;
    try {
      _autosaveTimer?.cancel();
      // Commit any in-progress IME composing text BEFORE reading the
      // controllers: on MIUI/Gboard the very last typed word can still be
      // in the composing region when the save button is tapped, and reading
      // the controller early dropped it. Unfocusing flushes the IME, then a
      // short delay lets the commit land.
      FocusManager.instance.primaryFocus?.unfocus();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      final entry = _buildEntry();
      try {
        await _enqueueWrite(entry);
      } catch (e) {
        debugPrint('[Save] Error saving entry: $e');
        if (mounted) {
          AnimatedSnack.show(
            context,
            L.tr(context, 'saveFailed'),
            type: SnackType.error,
          );
        }
        // Keep the editor open with all the typed text — do NOT navigate
        // away or crash, so nothing the user wrote is lost. Re-arm the tick
        // that was cancelled above, otherwise the rest of this session would
        // have no autosave at all.
        if (_autosave && mounted) _startAutosaveTimer();
        return;
      }
      if (!mounted) return;
      if (widget.entry == null) {
        // New entry: land on its preview instead of dropping the user back
        // onto the feed — they want to see what was just saved.
        Navigator.of(context).pushReplacement(
          fadeRoute(
            EntryDetailScreen(entry: entry, storage: _storage),
          ),
        );
      } else {
        // Editing: hand the fresh entry back so the detail screen can show
        // the updated preview (not stale data).
        Navigator.of(context).pop(entry);
      }
    } finally {
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = SettingsProvider.of(context).settings;
    return PopScope(
      // No way out of this screen that skips the disk: the system back
      // gesture, the AppBar arrow and `maybePop` all land in `_exitWithSave`,
      // which awaits the final write and only then pops. (`Navigator.pop`
      // itself bypasses PopScope, so the flush can close the route.)
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitWithSave();
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
        flexibleSpace: PremiumHeader(colors: AppTheme.headerColors(scheme)),
        title: Text(widget.entry == null
            ? L.tr(context, 'entryNew')
            : L.tr(context, 'entryEdit')),
        actions: [
          PressableIconButton(
            // Smooth pin toggle: the pin rotates 90° and springs to the
            // filled/outline state with a scale pop, themed by primary.
            onPressed: () => setState(() => _pinned = !_pinned),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => RotationTransition(
                turns: Tween(begin: 0.25, end: 0.0).animate(animation),
                child: ScaleTransition(
                  scale: Tween(begin: 0.5, end: 1.0).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
              ),
              child: Icon(
                _pinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                key: ValueKey(_pinned),
                color: _pinned
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          PressableIconButton(
            onPressed: () => _save(),
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<EntryType>(
              segments: [
                ButtonSegment(
                  value: EntryType.dream,
                  label: Text(L.tr(context, 'segDream')),
                  icon: const Icon(Icons.nightlight_round_rounded),
                ),
                ButtonSegment(
                  value: EntryType.life,
                  label: Text(L.tr(context, 'segLife')),
                  icon: const Icon(Icons.favorite_rounded),
                ),
                ButtonSegment(
                  value: EntryType.general,
                  label: Text(L.tr(context, 'segGeneral')),
                  icon: const Icon(Icons.edit_note_rounded),
                ),
                if (settings.tulpaEnabled || _type == EntryType.tulpa)
                  ButtonSegment(
                    value: EntryType.tulpa,
                    label: Text(L.tr(context, 'segTulpa')),
                    icon: const Icon(Icons.psychology_rounded),
                  ),
              ],
              selected: {_type},
              onSelectionChanged: (set) => setState(() {
                _type = set.first;
                if (_type != EntryType.dream) _isLucid = null;
                if (_type != EntryType.tulpa) _forcingDuration = null;
                if (_type != EntryType.dream) _dreamSigns = [];
              }),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 14),
            Text(
              L.tr(context, 'category'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                EntryCategory.none,
                EntryCategory.good,
                EntryCategory.bad,
                EntryCategory.random,
              ].map((c) {
                final selected = c == _category;
                // Custom pill instead of ChoiceChip: the selection eases
                // (colour + border + shadow) instead of the chip's internal
                // controller replaying — that replay flashed the PREVIOUS
                // category when switching fast.
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest.withValues(
                            alpha: 0.7,
                          ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? scheme.primary.withValues(alpha: 0.35)
                          : Colors.transparent,
                      width: 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    // No splash/highlight: the AnimatedContainer above owns
                    // the selected state — a ripple here lingered as the
                    // previous category's background when switching fast.
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      onTap: () => setState(() => _category = c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          L.tr(
                            context,
                            c == EntryCategory.none ? 'catAll' : c.labelKey,
                          ),
                          style: TextStyle(
                            color: selected
                                ? scheme.onPrimaryContainer
                                : scheme.onSurface,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded),
              title: Text(L.tr(context, 'editTime')),
              subtitle: Text(_formatDateTime(_createdAt)),
              trailing: const Icon(Icons.edit_calendar_rounded),
              onTap: _pickDateTime,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            // Smoothly animate the type-dependent sections when switching
            // between Сон / Жизнь / Заметка.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(_type),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_type == EntryType.tulpa) ...[
                    const SizedBox(height: 14),
                    ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.hourglass_bottom_rounded),
                title: Text(L.tr(context, 'forcingDuration')),
                subtitle: _forcingDuration == null
                    ? Text(L.tr(context, 'forcingHint'))
                    : Text(_formatDuration(_forcingDuration!)),
                trailing: const Icon(Icons.schedule_rounded),
                onTap: _pickForcing,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
            if (_type == EntryType.dream) ...[
              const SizedBox(height: 14),
              Text(
                L.tr(context, 'dreamKind'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(L.tr(context, 'dreamNormal')),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(L.tr(context, 'dreamLucid')),
                  ),
                ],
                selected: {_isLucid ?? false},
                onSelectionChanged: (set) =>
                    setState(() => _isLucid = set.first),
                showSelectedIcon: false,
              ),
            ],
            if (_type == EntryType.dream) ...[
              const SizedBox(height: 16),
              Text(
                L.tr(context, 'dreamSignsSection'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DreamSigns.presets.map((sign) {
                  final selected = _dreamSigns.contains(sign.id);
                  return FilterChip(
                    selected: selected,
                    showCheckmark: false,
                    avatar: Icon(sign.icon, size: 18),
                    label: Text(DreamSigns.label(context, sign.id)),
                    onSelected: (v) => setState(() {
                      if (v) {
                        _dreamSigns.add(sign.id);
                      } else {
                        _dreamSigns.remove(sign.id);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
        cursorOpacityAnimates: true,
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
                      controller: _signController,
                      contextMenuBuilder: (ctx, state) =>
                          buildLimitedContextMenu(ctx, state),
                      maxLength: 10,
                      decoration: InputDecoration(
                        hintText: L.tr(context, 'addSign'),
                        prefixIcon: const Icon(Icons.add_reaction_rounded),
                        counterText: '',
                      ),
                      onSubmitted: (_) => _addSign(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addSign,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              if (_dreamSigns
                  .where((s) => !DreamSigns.presets
                      .any((p) => p.id == s))
                  .isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _dreamSigns
                        .where((s) => !DreamSigns.presets
                            .any((p) => p.id == s))
                        .map((s) => AnimatedChip(
                              label: s,
                              withHash: false,
                              onDeleted: () =>
                                  setState(() => _dreamSigns.remove(s)),
                            ))
                        .toList(),
                  ),
                ),
            ],
            if (_type == EntryType.life) ...[
              // Wrap the life-only block in AnimatedSize so type-switching
              // (general → life) doesn't show a frame where the TextField is
              // laid out but visually empty — previously users saw the
              // floating "Л" лейбл дёргаться at the moment the section
              // mounted.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (settings.waterEnabled ||
                        widget.entry?.waterLiters != null) ...[
                      const SizedBox(height: 14),
                      TextField(
        cursorOpacityAnimates: true,
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
                        controller: _waterController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        contextMenuBuilder: (ctx, state) =>
                            buildLimitedContextMenu(ctx, state),
                        decoration: InputDecoration(
                          labelText: L.tr(context, 'water'),
                          hintText: L.tr(context, 'waterHint'),
                          prefixIcon: const Icon(Icons.water_drop_rounded),
                          counterText: '',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (settings.fastingEnabled || widget.entry?.fastingStart != null) ...[
                const SizedBox(height: 14),
                Text(
                  L.tr(context, 'fastingWindow'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _TimeTile(
                        label: L.tr(context, 'fastingFrom'),
                        value: _fastingStart,
                        onTap: () => _pickTimeField(
                          _fastingStart,
                          (v) => setState(() => _fastingStart = v),
                          context,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TimeTile(
                        label: L.tr(context, 'fastingTo'),
                        value: _fastingEnd,
                        onTap: () => _pickTimeField(
                          _fastingEnd,
                          (v) => setState(() => _fastingEnd = v),
                          context,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (settings.pomodoroEnabled || widget.entry?.pomodoroStart != null) ...[
                const SizedBox(height: 14),
                Text(
                  L.tr(context, 'pomodoro'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _TimeTile(
                        label: L.tr(context, 'pomodoroStart'),
                        value: _pomodoroStart,
                        onTap: () => _pickTimeField(
                          _pomodoroStart,
                          (v) => setState(() => _pomodoroStart = v),
                          context,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TimeTile(
                        label: L.tr(context, 'pomodoroEnd'),
                        value: _pomodoroEnd,
                        onTap: () => _pickTimeField(
                          _pomodoroEnd,
                          (v) => setState(() => _pomodoroEnd = v),
                          context,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    fadeRoute(const PomodoroScreen()),
                  ),
                  icon: const Icon(Icons.timer_rounded),
                  label: Text(L.tr(context, 'pomodoroStartFocus')),
                ),
              ],
            ],
            if ((settings.devHrtTracking || widget.entry?.hrtTime != null) && _type == EntryType.life) ...[
              const SizedBox(height: 14),
              Text(
                L.tr(context, 'hrtTime'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TimeTile(
                      label: L.tr(context, 'hrtTime'),
                      value: _hrtTime,
                      onTap: () => _pickTimeField(
                        _hrtTime,
                        (v) => setState(() => _hrtTime = v),
                        context,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
        cursorOpacityAnimates: true,
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
                      controller: _hrtDosageController,
                      contextMenuBuilder: (ctx, state) =>
                          buildLimitedContextMenu(ctx, state),
                      maxLength: 5,
                      decoration: InputDecoration(
                        hintText: L.tr(context, 'hrtDosage'),
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
                  ],
                ],
              ),
            ),
            // The title is editable both when creating and when editing an
            // entry — previously it was hidden entirely on the edit screen.
            const SizedBox(height: 16),
            TextField(
        cursorOpacityAnimates: true,
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
              controller: _titleController,
              maxLength: 100,
              buildCounter: animatedFieldCounter,
              inputFormatters: const [EmDashInputFormatter()],
              contextMenuBuilder: (ctx, state) =>
                  buildLimitedContextMenu(ctx, state),
              decoration: InputDecoration(
                hintText: L.tr(context, 'titleHint'),
                prefixIcon: const Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 16),
            if (!_previewMode)
              _MarkdownToolbar(controller: _contentController),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SegButton(
                    label: L.tr(context, 'editTab'),
                    icon: Icons.edit_rounded,
                    selected: !_previewMode,
                    onTap: () => setState(() => _previewMode = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SegButton(
                    label: L.tr(context, 'previewTab'),
                    icon: Icons.visibility_rounded,
                    selected: _previewMode,
                    onTap: () => setState(() => _previewMode = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Voice dictation is available for EVERY entry type (not just
            // dreams) — a single shared button above the content field.
            Align(
              alignment: Alignment.centerLeft,
              child: _VoiceButton(
                listening: _listening,
                onPressed: _toggleVoice,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(sizeFactor: animation, child: child),
              ),
              child: _previewMode
                  ? Container(
                      key: const ValueKey('preview'),
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 140),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: _contentController.text.trim().isEmpty
                          ? Text(
                              L.tr(context, 'previewEmpty'),
                              style: TextStyle(
                                color: scheme.onSurface.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            )
                          : MarkdownBody(
                              data: _contentController.text,
                              selectable: true,
                              // Keep the user's own line breaks: a single \n
                              // renders as a real break, not a collapsed space.
                              softLineBreak: true,
                              styleSheet: MarkdownStyleSheet.fromTheme(
                                Theme.of(context),
                              ).copyWith(
                                p: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(height: 1.6),
                              ),
                            ),
                    )
                  : TextField(
        cursorOpacityAnimates: true,
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
                      key: const ValueKey('editor'),
                      controller: _contentController,
                      inputFormatters: const [EmDashInputFormatter()],
                      contextMenuBuilder: (ctx, state) =>
                          buildLimitedContextMenu(ctx, state),
                      maxLength: 800000,
                      decoration: InputDecoration(
                        hintText: L.tr(context, 'contentHint'),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                        counterText: '',
                      ),
                      // No maxLines: the field grows with the text so the
                      // whole page scrolls as ONE unit. A capped field (e.g.
                      // maxLines: 10) scrolls internally, which made long
                      // entries feel like they were "split" into per-paragraph
                      // swipes instead of the page gliding as a whole.
                      maxLines: null,
                      minLines: 5,
                    ),
            ),
            const SizedBox(height: 20),
            Text(
              L.tr(context, 'mood'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (i) {
                final value = i + 1;
                final active = value <= _mood;
                return IconButton(
                  onPressed: () => setState(() => _mood = value),
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      active
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      key: ValueKey(active),
                      color: active
                          ? scheme.primary
                          : scheme.onSurface.withValues(alpha: 0.3),
                      size: 32,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            Text(
              L.tr(context, 'tags'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
        cursorOpacityAnimates: true,
        magnifierConfiguration: TextMagnifierConfiguration.disabled,
                    controller: _tagController,
                    contextMenuBuilder: (ctx, state) =>
                        buildLimitedContextMenu(ctx, state),
                    maxLength: 10,
                    decoration: InputDecoration(
                      hintText: L.tr(context, 'addTag'),
                      prefixIcon: const Icon(Icons.tag_rounded),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags
                  .map((t) => AnimatedChip(
                        label: t,
                        withHash: true,
                        onDeleted: () => setState(() => _tags.remove(t)),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Small segmented button used for the Редактор/Превью toggle above the
/// body field. The selection eases smoothly instead of snapping.
class _SegButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SegButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? scheme.primary.withValues(alpha: 0.35)
              : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
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

class _MarkdownToolbar extends StatelessWidget {
  final TextEditingController controller;

  const _MarkdownToolbar({required this.controller});

  void _wrap(String left, String right) {
    final text = controller.text;
    final sel = controller.selection;
    final start = sel.start;
    final end = sel.end;
    if (start == end) {
      final pos = start;
      final newText = '${text.substring(0, pos)}$left$right${text.substring(pos)}';
      controller.text = newText;
      controller.selection = TextSelection.collapsed(offset: pos + left.length);
    } else {
      final selected = text.substring(start, end);
      final newText = '${text.substring(0, start)}$left$selected$right${text.substring(end)}';
      controller.text = newText;
      controller.selection = TextSelection(baseOffset: start, extentOffset: start + left.length + selected.length + right.length);
    }
  }

  void _insert(String text) {
    final pos = controller.selection.start;
    final cur = controller.text;
    controller.text = '${cur.substring(0, pos)}$text${cur.substring(pos)}';
    controller.selection = TextSelection.collapsed(offset: pos + text.length);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _MdBtn(icon: Icons.format_bold_rounded, label: 'B', onTap: () => _wrap('**', '**')),
          _MdBtn(icon: Icons.format_italic_rounded, label: 'I', onTap: () => _wrap('*', '*')),
          _MdBtn(icon: Icons.format_strikethrough_rounded, label: 'S', onTap: () => _wrap('~~', '~~')),
          const SizedBox(width: 4),
          _MdBtn(icon: Icons.title_rounded, label: 'H1', onTap: () => _insert('\n# ')),
          _MdBtn(icon: Icons.title_rounded, label: 'H2', onTap: () => _insert('\n## ')),
          _MdBtn(icon: Icons.title_rounded, label: 'H3', onTap: () => _insert('\n### ')),
          const SizedBox(width: 4),
          _MdBtn(icon: Icons.format_list_bulleted_rounded, label: '•', onTap: () => _insert('\n- ')),
          _MdBtn(icon: Icons.format_list_numbered_rounded, label: '1.', onTap: () => _insert('\n1. ')),
          const SizedBox(width: 4),
          _MdBtn(icon: Icons.code_rounded, label: '<>', onTap: () => _wrap('`', '`')),
          _MdBtn(icon: Icons.integration_instructions_rounded, label: '```', onTap: () => _insert('\n```\n\n```\n')),
          const SizedBox(width: 4),
          _MdBtn(icon: Icons.format_quote_rounded, label: '›', onTap: () => _insert('\n> ')),
          _MdBtn(icon: Icons.horizontal_rule_rounded, label: '—', onTap: () => _insert('\n---\n')),
        ],
      ),
    );
  }
}

class _MdBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MdBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: scheme.primary),
                const SizedBox(width: 2),
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            Text(
              value ?? '--:--',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Voice-input button with a breathing pulse + colour shift while
/// listening, and a smooth icon/label cross-fade on toggle.
class _VoiceButton extends StatefulWidget {
  final bool listening;
  final VoidCallback onPressed;

  const _VoiceButton({
    required this.listening,
    required this.onPressed,
  });

  @override
  State<_VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<_VoiceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(_VoiceButton old) {
    super.didUpdateWidget(old);
    if (widget.listening && !old.listening) {
      _pulse.repeat(reverse: true);
    } else if (!widget.listening && old.listening) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      scale: widget.listening ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      child: FilledButton.icon(
        onPressed: widget.onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: widget.listening
              ? scheme.errorContainer
              : scheme.primaryContainer,
          foregroundColor: widget.listening
              ? scheme.onErrorContainer
              : scheme.onPrimaryContainer,
        ),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            widget.listening
                ? Icons.stop_circle_rounded
                : Icons.mic_rounded,
            key: ValueKey(widget.listening),
          ),
        ),
        label: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: Text(
            widget.listening
                ? L.tr(context, 'listening')
                : L.tr(context, 'voiceInput'),
            key: ValueKey(widget.listening),
          ),
        ),
      ),
    );
  }
}
