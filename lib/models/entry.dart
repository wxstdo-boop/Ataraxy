import 'package:intl/intl.dart';

enum EntryType { dream, life, general, tulpa }

extension EntryTypeExtension on EntryType {
  String get labelKey {
    switch (this) {
      case EntryType.dream:
        return 'typeDream';
      case EntryType.life:
        return 'typeLife';
      case EntryType.general:
        return 'typeGeneral';
      case EntryType.tulpa:
        return 'typeTulpa';
    }
  }
}

enum EntryCategory { none, good, bad, random }

extension EntryCategoryExtension on EntryCategory {
  String get labelKey {
    switch (this) {
      case EntryCategory.none:
        return 'catAll';
      case EntryCategory.good:
        return 'catGood';
      case EntryCategory.bad:
        return 'catBad';
      case EntryCategory.random:
        return 'catRandom';
    }
  }
}

class JournalEntry {
  final String id;
  final EntryType type;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int mood; // 1..5
  final List<String> tags;
  final bool? isLucid; // только для снов: true — осознанный, false — обычный
  final Duration? forcingDuration; // только для тульп: длительность форсинга
  final List<String> dreamSigns; // только для снов: частые явления
  final EntryCategory category; // настроение записи: хороший/плохой/случайный
  final double? waterLiters; // жизнь: сколько литров выпил
  final String? fastingStart; // жизнь: начало голодания "HH:mm"
  final String? fastingEnd; // жизнь: конец голодания "HH:mm"
  final String? pomodoroStart; // жизнь: начало фокуса "HH:mm"
  final String? pomodoroEnd; // жизнь: конец фокуса "HH:mm"
  final bool pinned; // закреплена ли запись
  final String? hrtTime; // HRT: время приёма "HH:mm"
  final String? hrtDosage; // HRT: дозировка

  const JournalEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.mood = 3,
    this.tags = const [],
    this.isLucid,
    this.forcingDuration,
    this.dreamSigns = const [],
    this.category = EntryCategory.none,
    this.waterLiters,
    this.fastingStart,
    this.fastingEnd,
    this.pomodoroStart,
    this.pomodoroEnd,
    this.pinned = false,
    this.hrtTime,
    this.hrtDosage,
  });

  JournalEntry copyWith({
    EntryType? type,
    String? title,
    String? content,
    DateTime? updatedAt,
    int? mood,
    List<String>? tags,
    bool? isLucid,
    bool clearForcing = false,
    Duration? forcingDuration,
    List<String>? dreamSigns,
    EntryCategory? category,
    double? waterLiters,
    String? fastingStart,
    String? fastingEnd,
    String? pomodoroStart,
    String? pomodoroEnd,
    bool clearWater = false,
    bool clearFasting = false,
    bool clearPomodoro = false,
    bool? pinned,
    String? hrtTime,
    String? hrtDosage,
    bool clearHrt = false,
  }) {
    return JournalEntry(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mood: mood ?? this.mood,
      tags: tags ?? this.tags,
      isLucid: type != null && type != EntryType.dream
          ? null
          : (isLucid ?? this.isLucid),
      forcingDuration: clearForcing
          ? null
          : (type != null && type != EntryType.tulpa
              ? null
              : (forcingDuration ?? this.forcingDuration)),
      dreamSigns: type != null && type != EntryType.dream
          ? const []
          : (dreamSigns ?? this.dreamSigns),
      category: category ?? this.category,
      waterLiters: clearWater || (type != null && type != EntryType.life)
          ? null
          : (waterLiters ?? this.waterLiters),
      fastingStart: clearFasting || (type != null && type != EntryType.life)
          ? null
          : (fastingStart ?? this.fastingStart),
      fastingEnd: clearFasting || (type != null && type != EntryType.life)
          ? null
          : (fastingEnd ?? this.fastingEnd),
      pomodoroStart: clearPomodoro || (type != null && type != EntryType.life)
          ? null
          : (pomodoroStart ?? this.pomodoroStart),
      pomodoroEnd: clearPomodoro || (type != null && type != EntryType.life)
          ? null
          : (pomodoroEnd ?? this.pomodoroEnd),
      pinned: pinned ?? this.pinned,
      hrtTime: clearHrt
          ? null
          : (type != null && type != EntryType.life
              ? null
              : (hrtTime ?? this.hrtTime)),
      hrtDosage: clearHrt
          ? null
          : (type != null && type != EntryType.life
              ? null
              : (hrtDosage ?? this.hrtDosage)),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'mood': mood,
        'tags': tags,
        'isLucid': isLucid,
        'forcingDuration': forcingDuration?.inMinutes,
        'dreamSigns': dreamSigns,
        'category': category.name,
        'waterLiters': waterLiters,
        'fastingStart': fastingStart,
        'fastingEnd': fastingEnd,
        'pomodoroStart': pomodoroStart,
        'pomodoroEnd': pomodoroEnd,
        'pinned': pinned,
        'hrtTime': hrtTime,
        'hrtDosage': hrtDosage,
      };

  /// Defensive parser: never throws. Missing / invalid id, createdAt,
  /// or updatedAt are recovered with fallbacks so a single malformed
  /// entry can't abort an import or vanish on the next load. `loadEntries`
  /// already has a per-item try-catch, but defensive fromJson keeps
  /// behavior consistent with ChatMessage / FavoriteActivity.
  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = (rawId is String && rawId.isNotEmpty)
        ? rawId
        : 'imported-${DateTime.now().microsecondsSinceEpoch}-${rawId.hashCode}';

    DateTime parseDate(dynamic v) {
      if (v is String && v.isNotEmpty) {
        final dt = DateTime.tryParse(v);
        if (dt != null) return dt;
      } else if (v is int) {
        return DateTime.fromMillisecondsSinceEpoch(v);
      }
      return DateTime.now();
    }

    final type = EntryType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => EntryType.general,
    );

    return JournalEntry(
      id: id,
      type: type,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      mood: (json['mood'] as int?) ?? 3,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isLucid: json['isLucid'] as bool?,
      forcingDuration: json['forcingDuration'] == null
          ? null
          : (json['forcingDuration'] is int
              ? Duration(minutes: json['forcingDuration'] as int)
              : null),
      dreamSigns: (json['dreamSigns'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      category: EntryCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => EntryCategory.none,
      ),
      waterLiters: (json['waterLiters'] as num?)?.toDouble(),
      fastingStart: json['fastingStart'] as String?,
      fastingEnd: json['fastingEnd'] as String?,
      pomodoroStart: json['pomodoroStart'] as String?,
      pomodoroEnd: json['pomodoroEnd'] as String?,
      pinned: (json['pinned'] as bool?) ?? false,
      hrtTime: json['hrtTime'] as String?,
      hrtDosage: json['hrtDosage'] as String?,
    );
  }

  String get formattedDate =>
      DateFormat('d MMM y, HH:mm', 'ru_RU').format(createdAt);
}
