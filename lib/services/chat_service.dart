import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:dream_journal/models/chat_message.dart';

class ChatService {
  static const String _boxName = 'chat_messages';
  static const String _key = 'messages';

  Future<Box> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  Future<List<ChatMessage>> loadMessages() async {
    final box = await _openBox();
    final rawList = box.get(_key) as List<dynamic>? ?? [];
    return rawList
        .map((e) {
          try {
            return ChatMessage.fromJson(
              jsonDecode(e) as Map<String, dynamic>,
            );
          } catch (err, st) {
            debugPrint('ChatService: dropped malformed favorite: $err\n$st');
            return null;
          }
        })
        .whereType<ChatMessage>()
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> addMessage(ChatMessage message) async {
    final messages = await loadMessages();
    messages.add(message);
    await _save(messages);
  }

  Future<void> deleteMessage(String id) async {
    final messages = await loadMessages();
    messages.removeWhere((m) => m.id == id);
    await _save(messages);
  }

  Future<void> togglePin(String id) async {
    final messages = await loadMessages();
    final idx = messages.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    messages[idx] = messages[idx].copyWith(pinned: !messages[idx].pinned);
    await _save(messages);
  }

  Future<void> _save(List<ChatMessage> messages) async {
    final box = await _openBox();
    final raw = messages.map((m) => jsonEncode(m.toJson())).toList();
    await box.put(_key, raw);
  }

  Future<void> saveAll(List<ChatMessage> messages) async {
    await _save(messages);
  }

  Future<void> updateMessage(ChatMessage updated) async {
    final messages = await loadMessages();
    final idx = messages.indexWhere((m) => m.id == updated.id);
    if (idx < 0) return;
    messages[idx] = updated;
    await _save(messages);
  }
}
