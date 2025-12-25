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
      return Chat(
        id: (json['id'] ?? 0) as int,
        type: json['type'] != null
            ? ChatType.values.firstWhere(
                (e) => e.toString().split('.').last == json['type'].toString(),
                orElse: () => ChatType.private,
              )
            : ChatType.private,
        name: json['name'] as String?,
        avatar: json['avatar'] as String?,
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
                  return null;
                }
              }).whereType<User>().toList();
              
              return parsed;
            } else {
              return <User>[];
            }
          } catch (e) {
            return <User>[];
          }
        })(),
        lastMessageSender: json['lastMessageSender'] != null
            ? (() {
                try {
                  return User.fromJson(
                      json['lastMessageSender'] as Map<String, dynamic>);
                } catch (e) {
                  return null;
                }
              })()
            : null,
        lastMessage: json['lastMessage'] as String?,
        lastMessageAt: json['lastMessageAt'] != null
            ? DateTime.tryParse(json['lastMessageAt'] as String)
            : null,
        unreadCount: (json['unreadCount'] ?? 0) as int,
        createdAt: json['createdAt'] != null
            ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now())
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? (DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now())
            : DateTime.now(),
      );
    } catch (e, stackTrace) {
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

