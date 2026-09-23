import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ataraxy/models/chat_message.dart';
import 'package:ataraxy/models/entry.dart';
import 'package:ataraxy/models/favorite_activity.dart';
import 'package:ataraxy/models/settings.dart';
import 'package:ataraxy/services/chat_service.dart';
import 'package:ataraxy/services/favorite_activity_service.dart';
import 'package:ataraxy/services/settings_service.dart';

/// Утилита для правильной обработки UTF-8 кодировки
class JsonHelper {
  static String encodeSafe(dynamic object) => jsonEncode(object);

  static dynamic decodeSafe(String string) => jsonDecode(string);
}

/// Aggregated result of an import pass. The settings snackbar uses this
/// to surface what actually happened — instead of a single binary
/// "done" line — so the user sees, e.g., "imported X entries, Y media
/// files couldn't be located on this device". Cross-device restores
/// (laptop → phone, fresh install) always degrade on `mediaMissing`,
/// which the UI must call out honestly.
class ImportSummary {
  final int entriesChanged;
  final int entriesSkipped;
  final int favoritesParsed;
  final int favoritesSkipped;
  final int favoritesMediaRelocated;
  final int favoritesMediaMissing;
  final int activitiesParsed;
  final int activitiesSkipped;
  final int activitiesTrimmed;
  final bool settingsImported;

  const ImportSummary({
    this.entriesChanged = 0,
    this.entriesSkipped = 0,
    this.favoritesParsed = 0,
    this.favoritesSkipped = 0,
    this.favoritesMediaRelocated = 0,
    this.favoritesMediaMissing = 0,
    this.activitiesParsed = 0,
    this.activitiesSkipped = 0,
    this.activitiesTrimmed = 0,
    this.settingsImported = false,
  });

  bool get hasMediaIssue => favoritesMediaMissing > 0;
}

class StorageService {
  /// Entries live in a Hive box under ONE KEY PER ENTRY (`entry_<id>`), not
  /// as a single list. Why it matters: autosave ticks every second while
  /// typing, and entries can be up to 800k chars. The old layout re-read,
  /// re-parsed and re-encoded the ENTIRE list on every single write — on a
  /// mid-range device (Redmi) those synchronous JSON passes on the UI
  /// isolate piled up (the 1s timer didn't wait for the previous save),
  /// spiking CPU/memory until the OS killed the app mid-typing ("kicked
  /// back to the home screen"). Writing one key per entry keeps each save
  /// O(1) regardless of how many entries exist.
  static const String _boxName = 'journal_entries';
  static const String _key = 'entries'; // legacy single-list key (Hive)
  static const String _legacyPrefsKey = 'journal_entries';
  static const String _keyPrefix = 'entry_';
  // Tombstones: ids of entries the user deleted on THIS device, stored in
  // the same box under `deleted_<id>` = ISO timestamp. When data protection
  // is enabled, an import skips any backup entry whose id has a tombstone,
  // so previously-deleted entries never come back via an old backup.
  static const String _deletedPrefix = 'deleted_';

  /// Per-instance migration latch. Migration itself is idempotent (same
  /// source data → same keys), so two instances migrating concurrently is
  /// harmless; the latch just avoids repeating the scan within one instance.
  Future<void>? _migration;

  Future<Box> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  static String _entryKey(String id) => '$_keyPrefix$id';

  /// Ensures legacy data (old Hive list key + old SharedPreferences list)
  /// has been migrated into per-entry keys exactly once, then returns the
  /// current raw map (entry key → raw JSON string).
  Future<Map<String, String>> _rawMap() async {
    _migration ??= _doMigrate();
    await _migration;
    final box = await _openBox();
    return _readAll(box);
  }

  Future<void> _doMigrate() async {
    try {
      await _doMigrateInner();
    } catch (e) {
      // A migration hiccup (e.g. SharedPreferences racing with another
      // instance) must NEVER block saving or loading entries — the
      // per-entry keys are already in place for everyone who's past their
      // first launch. Swallow + log so addEntry/loadEntries keep working.
      debugPrint('Storage: migration failed (non-fatal): $e');
    }
  }

  Future<void> _doMigrateInner() async {
    final box = await _openBox();
    final legacyHive = (box.get(_key) as List<dynamic>?)?.cast<String>();
    final prefs = await SharedPreferences.getInstance();
    final legacyPrefs = prefs.getStringList(_legacyPrefsKey) ?? const [];
    final combined = <String>[...?legacyHive, ...legacyPrefs];
    if (combined.isEmpty) {
      if (box.get(_key) != null) await box.delete(_key);
      return;
    }
    var migrated = 0;
    for (final raw in combined) {
      try {
        final id =
            (jsonDecode(raw) as Map<String, dynamic>)['id'] as String?;
        if (id != null && id.isNotEmpty) {
          await box.put(_entryKey(id), raw);
          migrated++;
        }
      } catch (e) {
        debugPrint('Storage: Skipped malformed legacy entry: $e');
      }
    }
    if (box.get(_key) != null) await box.delete(_key);
    // Only drop the prefs copy when every entry made it across — otherwise
    // a partially failed migration is retried on the next StorageService
    // instance instead of losing data.
    if (migrated == combined.length) {
      await prefs.remove(_legacyPrefsKey);
    }
    debugPrint('Storage: Migrated $migrated legacy entries to per-entry keys');
  }

  Map<String, String> _readAll(Box box) {
    final map = <String, String>{};
    for (final key in box.keys) {
      if (key is String && key.startsWith(_keyPrefix)) {
        final v = box.get(key);
        if (v is String) map[key] = v;
      }
    }
    return map;
  }

  Future<List<JournalEntry>> loadEntries() async {
    final raw = await _rawMap();
    debugPrint('Storage: Loading ${raw.length} entries from Hive');

    // Decode + sort on a BACKGROUND isolate: entries can be up to 800k chars
    // and there can be hundreds of them. The old synchronous loop ran
    // jsonDecode + JournalEntry.fromJson on the UI isolate, which blocked
    // the first frame after the splash (and every pull-to-refresh / tab
    // reload) — the "app froze on Ataraxy" jank on mid-range devices.
    // Hive boxes stay isolate-bound, so we pass only the raw strings.
    final entries = await compute(_decodeEntries, raw.values.toList());
    debugPrint('Storage: Successfully loaded ${entries.length} entries');
    return entries;
  }

  Future<void> saveEntries(List<JournalEntry> entries) async {
    debugPrint('Storage: Saving ${entries.length} entries');
    await _rawMap(); // migrate first so legacy data isn't dropped
    final box = await _openBox();
    for (final e in entries) {
      await box.put(_entryKey(e.id), jsonEncode(e.toJson()));
    }
    debugPrint('Storage: Entries saved successfully');
  }

  Future<void> addEntry(JournalEntry entry) async {
    debugPrint('Storage: Adding entry: ${entry.title}');
    await _rawMap(); // migrate first so we don't overwrite legacy data
    final box = await _openBox();
    await box.put(_entryKey(entry.id), jsonEncode(entry.toJson()));
    debugPrint('Storage: Entry saved successfully');
  }

  Future<void> updateEntry(JournalEntry entry) async {
    await _rawMap();
    final box = await _openBox();
    await box.put(_entryKey(entry.id), jsonEncode(entry.toJson()));
  }

  /// Single-entry read straight from the box. Screens that receive an entry
  /// as a widget argument use this to check whether the stored copy has moved
  /// on since their snapshot was taken, instead of trusting it.
  Future<JournalEntry?> readEntry(String id) async {
    if (id.isEmpty) return null;
    await _rawMap();
    final box = await _openBox();
    final raw = box.get(_entryKey(id));
    if (raw is! String) return null;
    try {
      return JournalEntry.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (e) {
      debugPrint('Storage: readEntry($id) failed: $e');
      return null;
    }
  }

  /// Read-modify-write a handful of metadata fields without ever rebuilding
  /// the entry from an in-memory copy. Toggling a pin from the feed used to
  /// persist the whole object the feed happened to be holding, which could be
  /// a snapshot taken before an autosave landed — the newer text went back
  /// out of the box and the user's words vanished. Patching the stored JSON
  /// touches only the listed keys, so the body on disk stays authoritative.
  Future<void> patchEntry(String id, Map<String, dynamic> fields) async {
    if (id.isEmpty || fields.isEmpty) return;
    await _rawMap();
    final box = await _openBox();
    final key = _entryKey(id);
    final raw = box.get(key);
    if (raw is! String) return;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      map.addAll(fields);
      await box.put(key, jsonEncode(map));
    } catch (e) {
      debugPrint('Storage: patchEntry($id) failed: $e');
    }
  }

  /// Manual (drag-and-drop) order: ids only, never entry bodies. The feed
  /// used to persist the entire in-memory list on every reorder, which both
  /// raced with the editor's autosave and rewrote entries nobody had
  /// touched. Storing just the id sequence removes that failure mode.
  static const String _manualOrderKey = 'manual_order';

  Future<List<String>> loadManualOrder() async {
    await _rawMap();
    final box = await _openBox();
    final raw = box.get(_manualOrderKey);
    if (raw is! String) return const [];
    try {
      return (jsonDecode(raw) as List).whereType<String>().toList();
    } catch (e) {
      debugPrint('Storage: manual order decode failed: $e');
      return const [];
    }
  }

  Future<void> saveManualOrder(List<String> ids) async {
    await _rawMap();
    final box = await _openBox();
    await box.put(_manualOrderKey, jsonEncode(ids));
  }

  Future<void> deleteEntry(String id) async {
    await _rawMap();
    final box = await _openBox();
    await box.delete(_entryKey(id));
    // Remember the deletion so imports can skip resurrecting this entry.
    await box.put(
      '$_deletedPrefix$id',
      DateTime.now().toIso8601String(),
    );
  }

  /// Brings a previously-deleted entry back (used by the undo-snackbar in
  /// the detail screen). Re-inserts the entry and removes its tombstone so
  /// a later import won't treat it as deliberately deleted.
  Future<void> restoreEntry(JournalEntry entry) async {
    await _rawMap();
    final box = await _openBox();
    await box.put(_entryKey(entry.id), jsonEncode(entry.toJson()));
    await box.delete('$_deletedPrefix${entry.id}');
    debugPrint('Storage: Restored entry: ${entry.title}');
  }

  Future<String> exportToJson() async {
    final entries = await loadEntries();
    final settingsService = SettingsService();
    final settings = await settingsService.load();
    final chatService = ChatService();
    final favorites = await chatService.loadMessages();
    final activityService = FavoriteActivityService();
    final activities = await activityService.load();
    final json = {
      'app': 'Ataraxy',
      'version': 2,
      'entries': entries.map((e) => e.toJson()).toList(),
      'favorites': favorites.map((f) => f.toJson()).toList(),
      'activities': activities.map((a) => a.toJson()).toList(),
      'settings': settings.toJson(),
      'aiChat': await loadAiChat(),
      'savedAiKeys': await loadSavedAiKeys(),
      'charset': 'utf-8',
    };
    return JsonHelper.encodeSafe(json);
  }

  /// Читает файл в UTF-8 с fallback на Latin-1
  static String readFileWithEncoding(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('Файл не найден: $filePath');
    }
    final bytes = file.readAsBytesSync();
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  /// Imports a JSON backup. Per-item parse failures are isolated so a
  /// single malformed favorite / activity / journal entry can never abort
  /// the whole section. Counts of every category are returned via
  /// [ImportSummary] so the caller can show the user a meaningful
  /// snackbar instead of a single binary yes/no.
  ///
  /// NOTE on cross-device media: backups only carry media *paths*, not
  /// binary files. When the path doesn't exist on the importing device
  /// (e.g. a fresh install on a different phone), we look up the same
  /// basename under the current `getApplicationDocumentsDirectory()
  /// /favorites` — if a file is genuinely there, the favorite's
  /// mediaUrl is rewritten to its new on-disk location; otherwise
  /// `favoritesMediaMissing` is incremented and the UI shows a
  /// "media missing" placeholder. Truly transporting binaries across
  /// devices requires zipping the `favorites/` dir into the backup —
  /// that's a separate feature.
  Future<ImportSummary> importFromJson(String raw) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      final cleaned = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
      decoded = jsonDecode(cleaned);
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Неверный формат: ожидался JSON-объект');
    }

    // Outer counters — declared in the top-level scope so favorites
    // and activities blocks can write into them. `_lastImportFavMeta`
    // (an earlier hacky design) was removed; this is the canonical state.
    final rawEntries =
        (decoded['entries'] as List<dynamic>? ?? []).cast<dynamic>();
    var entriesSkipped = 0;

    final rawFavorites =
        (decoded['favorites'] as List<dynamic>? ?? []).cast<dynamic>();
    var favoritesSkipped = 0;
    var favoritesMediaRelocated = 0;
    var favoritesMediaMissing = 0;

    final rawActivities =
        (decoded['activities'] as List<dynamic>? ?? []).cast<dynamic>();
    var activitiesSkipped = 0;
    var activitiesTrimmed = 0;

    var settingsImported = false;

    // ---- Entries ----
    final list = <JournalEntry>[];
    for (final e in rawEntries) {
      try {
        list.add(JournalEntry.fromJson(e as Map<String, dynamic>));
      } catch (err) {
        entriesSkipped++;
        debugPrint('Import: skipped malformed entry: $err');
      }
    }
    debugPrint(
      'Import: Found ${list.length} entries (skipped $entriesSkipped)',
    );

    final existing = await loadEntries();
    final byId = {for (final e in existing) e.id: e};
    var entriesChanged = 0;

    // When data protection is on, skip backup entries whose ids were
    // deleted on this device (tombstones). The user asked for this: an old
    // backup must NOT bring back entries they already deleted.
    final protectDeleted = (await SettingsService().load()).protectDeletedOnImport;
    var entriesSkippedProtection = 0;
    if (protectDeleted) {
      final box = await _openBox();
      final tombstones = <String>{};
      for (final k in box.keys) {
        if (k is String && k.startsWith(_deletedPrefix)) {
          tombstones.add(k.substring(_deletedPrefix.length));
        }
      }
      final filtered = <JournalEntry>[];
      for (final entry in list) {
        if (tombstones.contains(entry.id)) {
          entriesSkippedProtection++;
        } else {
          filtered.add(entry);
        }
      }
      list
        ..clear()
        ..addAll(filtered);
      debugPrint(
        'Import: protection skipped $entriesSkippedProtection deleted entries',
      );
    }

    for (final entry in list) {
      if (!byId.containsKey(entry.id) || byId[entry.id] != entry) {
        byId[entry.id] = entry;
        entriesChanged++;
      }
    }
    await saveEntries(byId.values.toList());

    // ---- Favorites ----
    final favoritesList = <ChatMessage>[];
    for (final item in rawFavorites) {
      try {
        favoritesList.add(ChatMessage.fromJson(item as Map<String, dynamic>));
      } catch (err) {
        favoritesSkipped++;
        debugPrint('Import: skipped malformed favorite: $err');
      }
    }
    debugPrint(
      'Import: Found ${favoritesList.length} favorites (skipped $favoritesSkipped)',
    );

    if (favoritesList.isNotEmpty) {
      try {
        // Compute the local favorites dir ONCE so we can relocate media
        // paths from cross-device backups below.
        final appDir = await getApplicationDocumentsDirectory();
        final favoritesDir =
            '${appDir.path}${Platform.pathSeparator}favorites';

        final chatService = ChatService();
        final existingFavs = await chatService.loadMessages();
        final favById = {for (final f in existingFavs) f.id: f};
        for (final f in favoritesList) {
          var msg = f;
          if (f.mediaUrl != null && f.mediaType != ChatMediaType.text) {
            // If the absolute path from the backup doesn't exist on
            // this device, try to find the same basename in our
            // local favorites dir and rewrite mediaUrl there. If
            // neither location has the file, keep the favorite and
            // let the UI show a "missing" placeholder.
            if (!File(f.mediaUrl!).existsSync()) {
              final basename =
                  f.mediaUrl!.split(Platform.pathSeparator).last;
              final candidate =
                  '$favoritesDir${Platform.pathSeparator}$basename';
              if (File(candidate).existsSync()) {
                msg = f.copyWith(mediaUrl: candidate);
                favoritesMediaRelocated++;
              } else {
                favoritesMediaMissing++;
              }
            }
          }
          favById[f.id] = msg;
        }
        if (favoritesMediaRelocated > 0 || favoritesMediaMissing > 0) {
          debugPrint(
            'Import favorites: relocated=$favoritesMediaRelocated '
            'missing-media=$favoritesMediaMissing',
          );
        }
        await chatService.saveAll(favById.values.toList());
      } catch (e) {
        debugPrint('Import favorites error: $e');
      }
    }

    // ---- Activities ----
    final activitiesList = <FavoriteActivity>[];
    for (final item in rawActivities) {
      try {
        activitiesList.add(
            FavoriteActivity.fromJson(item as Map<String, dynamic>));
      } catch (err) {
        activitiesSkipped++;
        debugPrint('Import: skipped malformed activity: $err');
      }
    }
    debugPrint(
      'Import: Found ${activitiesList.length} activities '
      '(skipped $activitiesSkipped)',
    );

    if (activitiesList.isNotEmpty) {
      try {
        final activityService = FavoriteActivityService();
        final existingActs = await activityService.load();
        final actById = {for (final a in existingActs) a.id: a};
        for (final a in activitiesList) {
          actById[a.id] = a;
        }
        final merged = actById.values.toList();
        merged.sort((a, b) {
          if (b.pinned && !a.pinned) return 1;
          if (a.pinned && !b.pinned) return -1;
          return b.createdAt.compareTo(a.createdAt);
        });
        final capped = merged.take(FavoriteActivityService.maxItems).toList();
        activitiesTrimmed = merged.length - capped.length;
        if (activitiesTrimmed > 0) {
          debugPrint(
            'Import activities: trimmed $activitiesTrimmed '
            '(cap ${FavoriteActivityService.maxItems})',
          );
        }
        await activityService.saveAll(capped);
      } catch (e) {
        debugPrint('Import activities error: $e');
      }
    }

    // ---- Settings ----
    if (decoded['settings'] != null) {
      try {
        final importedSettings = AppSettings.fromJson(
            decoded['settings'] as Map<String, dynamic>);
        final settingsService = SettingsService();
        await settingsService.save(importedSettings);
        debugPrint('Import: Settings imported successfully');
        settingsImported = true;
      } catch (e) {
        debugPrint('Import settings error: $e');
      }
    }

    // ---- Saved AI keys (must travel with the backup) ----
    if (decoded['savedAiKeys'] != null) {
      try {
        final keys = (decoded['savedAiKeys'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();
        await importSavedAiKeys(keys);
        debugPrint('Import: restored ${keys.length} saved AI keys');
      } catch (e) {
        debugPrint('Import saved AI keys error: $e');
      }
    }

    // ---- AI chat history ----
    if (decoded['aiChat'] != null) {
      try {
        final rawChat =
            (decoded['aiChat'] as List<dynamic>? ?? []).cast<dynamic>();
        final restored = <Map<String, String>>[];
        for (final item in rawChat) {
          try {
            final m = item as Map<String, dynamic>;
            restored.add({
              'role': m['role'] as String? ?? '',
              'content': m['content'] as String? ?? '',
              if (m['reasoning'] != null) 'reasoning': m['reasoning'] as String,
            });
          } catch (_) {
            // skip malformed message
          }
        }
        await saveAiChat(restored);
        debugPrint('Import: restored ${restored.length} AI chat messages');
      } catch (e) {
        debugPrint('Import AI chat error: $e');
      }
    }

    debugPrint(
        'Import: Total changed entries=$entriesChanged '
        'favorites=${favoritesList.length} activities=${activitiesList.length}');

    return ImportSummary(
      entriesChanged: entriesChanged,
      entriesSkipped: entriesSkipped,
      favoritesParsed: favoritesList.length,
      favoritesSkipped: favoritesSkipped,
      favoritesMediaRelocated: favoritesMediaRelocated,
      favoritesMediaMissing: favoritesMediaMissing,
      activitiesParsed: activitiesList.length,
      activitiesSkipped: activitiesSkipped,
      activitiesTrimmed: activitiesTrimmed,
      settingsImported: settingsImported,
    );
  }

  // ---- AI chat history ----

  static const String _aiChatBox = 'ai_chat_messages';
  static const String _aiChatKey = 'messages';

  Future<Box> _openAiChatBox() async {
    if (!Hive.isBoxOpen(_aiChatBox)) {
      await Hive.openBox(_aiChatBox);
    }
    return Hive.box(_aiChatBox);
  }

  /// Loads the persisted АДА chat history as (role, content) pairs.
  Future<List<Map<String, String>>> loadAiChat() async {
    final box = await _openAiChatBox();
    final raw = box.get(_aiChatKey) as List<dynamic>? ?? [];
    final out = <Map<String, String>>[];
    for (final e in raw) {
      try {
        final m = jsonDecode(e) as Map<String, dynamic>;
        out.add({
          'role': m['role'] as String? ?? '',
          'content': m['content'] as String? ?? '',
          if (m['reasoning'] != null) 'reasoning': m['reasoning'] as String,
        });
      } catch (_) {
        // skip malformed message
      }
    }
    return out;
  }

  /// Persists the АДА chat history (up to 2000 messages).
  Future<void> saveAiChat(List<Map<String, String>> messages) async {
    final box = await _openAiChatBox();
    final trimmed = messages.length > 2000
        ? messages.sublist(messages.length - 2000)
        : messages;
    await box.put(
      _aiChatKey,
      trimmed.map((m) => jsonEncode(m)).toList(),
    );
  }

  // ---- AI rewards (daily rewards / streak / points) ----

  static const String _rewardsKey = 'rewards';

  /// Loads the AI-reward state (streak, points, last rewarded day) or an
  /// empty map when nothing was ever saved.
  Future<Map<String, dynamic>> loadRewards() async {
    final box = await _openAiChatBox();
    final raw = box.get(_rewardsKey);
    if (raw is String) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        return m;
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  Future<void> saveRewards(Map<String, dynamic> data) async {
    final box = await _openAiChatBox();
    await box.put(_rewardsKey, jsonEncode(data));
  }

  // ---- Saved AI keys (up to 10, quickly switchable in Settings) ----

  static const String _savedAiKeysKey = 'saved_ai_keys';

  /// All keys the user has ever pasted into the AI key dialog (most recent
  /// first, capped at 10) — selectable from a dropdown in Settings.
  Future<List<String>> loadSavedAiKeys() async {
    final box = await _openAiChatBox();
    final raw = box.get(_savedAiKeysKey);
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    return const [];
  }

  /// Adds (or bumps to front) a key in the saved list; caps at 10.
  Future<List<String>> saveAiKeyToSaved(String key) async {
    final box = await _openAiChatBox();
    final list = (box.get(_savedAiKeysKey) as List? ?? const [])
        .whereType<String>()
        .toList();
    list.removeWhere((k) => k == key);
    list.insert(0, key);
    if (list.length > 10) list.removeRange(10, list.length);
    await box.put(_savedAiKeysKey, list);
    return list;
  }

  /// Removes one saved key. Returns the updated list.
  Future<List<String>> deleteSavedAiKey(String key) async {
    final box = await _openAiChatBox();
    final list = (box.get(_savedAiKeysKey) as List? ?? const [])
        .whereType<String>()
        .toList();
    list.remove(key);
    await box.put(_savedAiKeysKey, list);
    return list;
  }

  // ---- Saved AI keys: import/restore after a backup ----

  Future<void> importSavedAiKeys(List<String> keys) async {
    final box = await _openAiChatBox();
    await box.put(_savedAiKeysKey, keys);
  }

  // ---- AI provider choice (persisted across restarts) ----

  static const String _aiProviderKey = 'provider';

  /// Last active provider tab: 'free' | 'ada' | 'laguna'.
  Future<String> loadAiProvider() async {
    final box = await _openAiChatBox();
    final v = box.get(_aiProviderKey) as String?;
    if (v == 'ada') return 'ada';
    if (v == 'laguna') return 'laguna';
    if (v == 'groq') return 'groq';
    return 'free';
  }

  Future<void> saveAiProvider(String provider) async {
    final box = await _openAiChatBox();
    await box.put(_aiProviderKey, provider);
  }
}

/// Decodes raw entry JSON strings into [JournalEntry] models and sorts them
/// newest-first. Top-level (not a method) so [compute] can run it on a
/// background isolate — keeps the JSON pass off the UI thread.
List<JournalEntry> _decodeEntries(List<String> raws) {
  final entries = <JournalEntry>[];
  for (final e in raws) {
    try {
      entries.add(JournalEntry.fromJson(jsonDecode(e) as Map<String, dynamic>));
    } catch (e) {
      debugPrint('Storage: Failed to parse entry: $e');
    }
  }
  entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return entries;
}
