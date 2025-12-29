class User {
  final int id;
  final String username;
  final String email;
  final String? avatar;
  final bool? isOnline;
  final DateTime? lastSeen;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.avatar,
    this.isOnline,
    this.lastSeen,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Поддержка обоих форматов: camelCase и snake_case
    final avatarValue = json['avatar'] ?? json['avatar_url'];
    final avatar = avatarValue is String ? avatarValue : null;
    
    // Обрабатываем status/isOnline - может быть bool, String или null
    final statusValue = json['status'] ?? json['isOnline'];
    bool? isOnline;
    if (statusValue != null) {
      if (statusValue is bool) {
        isOnline = statusValue;
      } else if (statusValue is String) {
        isOnline = statusValue.toLowerCase() == 'online';
      }
    }
    
    // Обрабатываем lastSeen - может быть String или null
    final lastSeenValue = json['lastSeen'] ?? json['last_seen'];
    final lastSeenStr = lastSeenValue is String ? lastSeenValue : null;
    
    // Обрабатываем email - может быть String или другой тип
    final emailValue = json['email'];
    final email = emailValue is String ? emailValue : (emailValue?.toString() ?? '');
    
    // Обрабатываем username - может быть String или другой тип
    final usernameValue = json['username'];
    final username = usernameValue is String ? usernameValue : (usernameValue?.toString() ?? '');
    
    return User(
      id: (json['id'] ?? 0) as int,
      username: username,
      email: email,
      avatar: avatar,
      isOnline: isOnline,
      lastSeen: lastSeenStr != null
          ? DateTime.tryParse(lastSeenStr)
          : null,
      createdAt: (() {
        final createdAtValue = json['createdAt'] ?? json['created_at'];
        if (createdAtValue is String) {
          return DateTime.tryParse(createdAtValue) ?? DateTime.now();
        }
        return DateTime.now();
      })(),
      updatedAt: (() {
        final updatedAtValue = json['updatedAt'] ?? json['updated_at'];
        if (updatedAtValue is String) {
          return DateTime.tryParse(updatedAtValue) ?? DateTime.now();
        }
        return DateTime.now();
      })(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar': avatar,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

