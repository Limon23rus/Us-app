import 'user.dart';

enum ChatType {
  private,
  group,
}

class Chat {
  final int id;
  final ChatType type;
  final String? name;
  final String? avatar;
  final List<User> participants;
  final User? lastMessageSender;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Chat({
    required this.id,
    required this.type,
    this.name,
    this.avatar,
    required this.participants,
    this.lastMessageSender,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    try {
      // Безопасное преобразование int
      int _parseInt(dynamic value, int defaultValue) {
        if (value == null) return defaultValue;
        if (value is int) return value;
        if (value is String) {
          return int.tryParse(value) ?? defaultValue;
        }
        if (value is double) return value.toInt();
        return defaultValue;
      }

      // Безопасное преобразование String?
      String? _parseString(dynamic value) {
        if (value == null) return null;
        if (value is String) return value.isEmpty ? null : value;
        return value.toString();
      }

      return Chat(
        id: _parseInt(json['id'], 0),
        type: json['type'] != null
            ? ChatType.values.firstWhere(
                (e) => e.toString().split('.').last == json['type'].toString(),
                orElse: () => ChatType.private,
              )
            : ChatType.private,
        name: _parseString(json['name']),
        avatar: _parseString(json['avatar']),
        participants: (() {
          try {
            final participantsData = json['participants'];
            if (participantsData == null) {
              return <User>[];
            }
            
            if (participantsData is List) {
              final parsed = participantsData.map((p) {
                try {
                  if (p is Map<String, dynamic>) {
                    return User.fromJson(p);
                  } else if (p is int) {
                    // Если участник - это просто ID, создаем минимальный объект User
                    return User(
                      id: p,
                      username: 'Пользователь $p',
                      email: 'user$p@example.com',
                      avatar: null,
                      isOnline: null,
                      lastSeen: null,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                  } else {
                    return null;
                  }
                } catch (e) {
                  print('Error parsing participant: $e');
                  return null;
                }
              }).whereType<User>().toList();
              
              return parsed;
            } else {
              return <User>[];
            }
          } catch (e) {
            print('Error parsing participants: $e');
            return <User>[];
          }
        })(),
        lastMessageSender: json['lastMessageSender'] != null || json['last_message_sender'] != null
            ? (() {
                try {
                  final senderData = json['lastMessageSender'] ?? json['last_message_sender'];
                  if (senderData is Map<String, dynamic>) {
                    return User.fromJson(senderData);
                  }
                  return null;
                } catch (e) {
                  print('Error parsing lastMessageSender: $e');
                  return null;
                }
              })()
            : null,
        lastMessage: _parseString(json['lastMessage'] ?? json['last_message']),
        lastMessageAt: (() {
          final lastMessageAtStr = json['lastMessageAt'] ?? json['last_message_time'] ?? json['last_message_at'];
          if (lastMessageAtStr == null) return null;
          if (lastMessageAtStr is String) {
            final dt = DateTime.tryParse(lastMessageAtStr);
            return dt?.toLocal();
          }
          return null;
        })(),
        unreadCount: _parseInt(json['unreadCount'] ?? json['unread_count'], 0),
        createdAt: (() {
          final createdAtStr = json['createdAt'] ?? json['created_at'];
          if (createdAtStr == null) return DateTime.now();
          if (createdAtStr is String) {
            return DateTime.tryParse(createdAtStr)?.toLocal() ?? DateTime.now();
          }
          return DateTime.now();
        })(),
        updatedAt: (() {
          final updatedAtStr = json['updatedAt'] ?? json['updated_at'];
          if (updatedAtStr == null) return DateTime.now();
          if (updatedAtStr is String) {
            return DateTime.tryParse(updatedAtStr)?.toLocal() ?? DateTime.now();
          }
          return DateTime.now();
        })(),
      );
    } catch (e) {
      print('Error in Chat.fromJson: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'name': name,
      'avatar': avatar,
      'participants': participants.map((p) => p.toJson()).toList(),
      'lastMessageSender': lastMessageSender?.toJson(),
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'unreadCount': unreadCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String getDisplayName(User currentUser) {
    if (type == ChatType.group) {
      return name ?? 'Групповой чат';
    }
    
    if (participants.isEmpty) {
      return 'Неизвестный пользователь';
    }
    
    // Ищем другого пользователя (не текущего)
    User? otherUser;
    try {
      otherUser = participants.firstWhere(
        (p) => p.id != currentUser.id,
      );
    } catch (e) {
      // Если не нашли другого пользователя, используем первого
      if (participants.isNotEmpty) {
        otherUser = participants.first;
      }
    }
    
    return otherUser?.username ?? 'Неизвестный пользователь';
  }

  String? getDisplayAvatar(User currentUser) {
    if (type == ChatType.group) {
      return avatar;
    }
    if (participants.isEmpty) {
      return null;
    }
    
    // Ищем другого пользователя (не текущего)
    User? otherUser;
    try {
      otherUser = participants.firstWhere(
        (p) => p.id != currentUser.id,
      );
    } catch (e) {
      // Если не нашли другого пользователя, используем первого
      if (participants.isNotEmpty) {
        otherUser = participants.first;
      }
    }
    
    return otherUser?.avatar;
  }
}

