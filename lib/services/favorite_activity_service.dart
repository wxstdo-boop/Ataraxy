import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:dream_journal/models/favorite_activity.dart';

class FavoriteActivityService {
  static const String _boxName = 'favorite_activities';
  static const String _key = 'activities';
  static const int maxLength = 150;
  static const int maxItems = 15;

  Future<Box> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  Future<List<FavoriteActivity>> load() async {
    final box = await _openBox();
    final rawList = box.get(_key) as List<dynamic>? ?? [];
    return rawList
        .map((e) {
          try {
            return FavoriteActivity.fromJson(
              jsonDecode(e) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<FavoriteActivity>()
        .toList();
  }

  Future<void> saveAll(List<FavoriteActivity> activities) async {
    final box = await _openBox();
    final raw = activities.map((a) => jsonEncode(a.toJson())).toList();
    await box.put(_key, raw);
  }

  /// Adds [activity] unless the list is already at [maxItems].
  /// Returns `false` when the limit would be exceeded.
  /// Inserts at the TOP to match the screen's optimistic insert — the old
  /// append-here / insert-there mismatch made a fresh item appear at the
  /// bottom after every reload ("second from the bottom" bug).
  Future<bool> add(FavoriteActivity activity) async {
    final activities = await load();
    if (activities.length >= maxItems) return false;
    activities.insert(0, activity);
    await saveAll(activities);
    return true;
  }

  Future<void> update(FavoriteActivity activity) async {
    final activities = await load();
    final idx = activities.indexWhere((a) => a.id == activity.id);
    if (idx < 0) return;
    activities[idx] = activity;
    await saveAll(activities);
  }

  Future<void> delete(String id) async {
    final activities = await load();
    activities.removeWhere((a) => a.id == id);
    await saveAll(activities);
  }

  /// Flips the pinned flag of the activity with [id].
  Future<void> togglePin(String id) async {
    final activities = await load();
    final idx = activities.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    activities[idx] = activities[idx].copyWith(pinned: !activities[idx].pinned);
    await saveAll(activities);
  }
}
