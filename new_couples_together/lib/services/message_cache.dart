import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isSent,
    required this.time,
    this.date,
    this.isFile = false,
    this.fileName,
    this.fileSize,
    this.imagePath,
    this.reactions = const [],
    this.isStarred = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'] as String,
        isSent: json['isSent'] as bool,
        time: json['time'] as String,
        date: json['date'] as String?,
        isFile: json['isFile'] as bool? ?? false,
        fileName: json['fileName'] as String?,
        fileSize: json['fileSize'] as String?,
        imagePath: json['imagePath'] as String?,
        reactions: (json['reactions'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        isStarred: json['isStarred'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'isSent': isSent,
        'time': time,
        if (date != null) 'date': date,
        'isFile': isFile,
        if (fileName != null) 'fileName': fileName,
        if (fileSize != null) 'fileSize': fileSize,
        if (imagePath != null) 'imagePath': imagePath,
        if (reactions.isNotEmpty) 'reactions': reactions,
        'isStarred': isStarred,
      };

  ChatMessage copyWith({List<String>? reactions, bool? isStarred}) => ChatMessage(
        text: text,
        isSent: isSent,
        time: time,
        date: date,
        isFile: isFile,
        fileName: fileName,
        fileSize: fileSize,
        imagePath: imagePath,
        reactions: reactions ?? this.reactions,
        isStarred: isStarred ?? this.isStarred,
      );

  final String text;
  final bool isSent;
  final String time;
  final String? date;
  final bool isFile;
  final String? fileName;
  final String? fileSize;
  final String? imagePath;
  final List<String> reactions;
  final bool isStarred;

  bool get isImage => imagePath != null && !isFile;
}

class MessageCache {
  MessageCache._();

  static const _key = 'chat_messages_v1';

  static Future<List<ChatMessage>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key);
      if (raw == null || raw.isEmpty) return [];
      return raw
          .map((s) => ChatMessage.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      messages.map((m) => jsonEncode(m.toJson())).toList(),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
