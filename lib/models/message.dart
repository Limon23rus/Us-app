import 'user.dart';

enum MessageType {
  text,
  image,
  file,
  audio,
  video,
}

class Message {
  final int id;
  final int chatId;
  final User sender;
  final String content;
  final MessageType messageType;
  final String? fileUrl;
  final String? fileName;
  final bool isRead;
  final DateTime createdAt;
  final DateTime updatedAt;

  Message({
    required this.id,
    required this.chatId,
    required this.sender,
    required this.content,
    required this.messageType,
    this.fileUrl,
    this.fileName,
    this.isRead = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    try {
      // Поддержка обоих форматов: camelCase и snake_case
      final chatId = json['chatId'] ?? json['chat_id'] ?? 0;
      final messageTypeStr = json['messageType'] ?? json['message_type'] ?? 'text';
      final fileUrl = json['fileUrl'] ?? json['file_url'];
      final fileName = json['fileName'] ?? json['file_name'];
      final isRead = json['isRead'] ?? json['is_read'] ?? false;
      final createdAtStr = json['createdAt'] ?? json['created_at'];
      final updatedAtStr = json['updatedAt'] ?? json['updated_at'] ?? createdAtStr;
      
      // Обработка sender - может быть объектом или отдельными полями
      User sender;
      if (json['sender'] != null && json['sender'] is Map<String, dynamic>) {
        // Формат с объектом sender
        sender = User.fromJson(json['sender'] as Map<String, dynamic>);
      } else {
        // Формат с отдельными полями sender_id, sender_username, sender_avatar
        final senderId = json['sender_id'] ?? json['senderId'] ?? json['sender']?['id'] ?? 0;
        final senderUsername = json['sender_username'] ?? json['senderUsername'] ?? json['sender']?['username'] ?? 'Unknown';
        // sender_email может отсутствовать в ответе бэкенда, используем дефолтное значение
        final senderEmail = json['sender_email'] ?? json['senderEmail'] ?? json['sender']?['email'] ?? 'user$senderId@example.com';
        final senderAvatar = json['sender_avatar'] ?? json['senderAvatar'] ?? json['sender']?['avatar'] ?? json['sender']?['avatar_url'];
        
        sender = User(
          id: senderId as int,
          username: senderUsername as String,
          email: senderEmail as String,
          avatar: senderAvatar as String?,
          isOnline: null,
          lastSeen: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      
      return Message(
        id: (json['id'] ?? 0) as int,
        chatId: chatId as int,
        sender: sender,
        content: (json['content'] ?? '') as String,
        messageType: MessageType.values.firstWhere(
          (e) => e.toString().split('.').last == messageTypeStr.toString(),
          orElse: () => MessageType.text,
        ),
        fileUrl: fileUrl as String?,
        fileName: fileName as String?,
        isRead: isRead as bool,
        createdAt: createdAtStr != null
            ? _parseDateTime(createdAtStr as String)
            : DateTime.now(),
        updatedAt: updatedAtStr != null
            ? _parseDateTime(updatedAtStr as String)
            : DateTime.now(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'sender': sender.toJson(),
      'content': content,
      'messageType': messageType.toString().split('.').last,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toSendJson() {
    return {
      'chatId': chatId,
      'content': content,
      'messageType': messageType.toString().split('.').last,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
    };
  }

  /// Парсит строку даты и конвертирует в локальное время
  /// Бэкенд теперь всегда возвращает время в формате ISO 8601 с UTC (с 'Z' в конце)
  static DateTime _parseDateTime(String dateTimeStr) {
    try {
      // Парсим дату
      DateTime? dateTime = DateTime.tryParse(dateTimeStr);
      
      if (dateTime == null) {
        return DateTime.now();
      }
      
      // Если строка содержит 'Z' (UTC), DateTime.tryParse создает UTC DateTime
      // Если строка содержит offset, DateTime.tryParse создает DateTime с этим offset
      // Если часовой пояс не указан, DateTime.tryParse создает локальный DateTime
      
      // Проверяем, является ли DateTime UTC
      if (dateTime.isUtc) {
        // Это UTC, конвертируем в локальное время
        return dateTime.toLocal();
      } else {
        // Это локальное время, но если строка не содержала часового пояса,
        // предполагаем, что сервер вернул UTC время без указания часового пояса
        // Создаем UTC DateTime из компонентов и конвертируем в локальное
        final utcDateTime = DateTime.utc(
          dateTime.year,
          dateTime.month,
          dateTime.day,
          dateTime.hour,
          dateTime.minute,
          dateTime.second,
          dateTime.millisecond,
          dateTime.microsecond,
        );
        return utcDateTime.toLocal();
      }
    } catch (e) {
      return DateTime.now();
    }
  }
}

