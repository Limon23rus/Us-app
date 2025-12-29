import 'package:flutter/foundation.dart';
import '../models/chat.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';

class ChatProvider extends ChangeNotifier {
  final AuthProvider authProvider;
  
  List<Chat> _chats = [];
  bool _isLoading = false;
  String? _error;
  String? _lastError;

  ChatProvider({required this.authProvider}) {
    _setupSocketListeners();
  }

  List<Chat> get chats => _chats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get lastError => _lastError;

  void _setupSocketListeners() {
    final socketService = authProvider.socketService;
    if (socketService == null) return;

    socketService.onChatUpdated((data) {
      final chatId = data['id'] as int?;
      if (chatId != null) {
        _updateChatFromSocket(chatId, data);
      }
    });
  }

  Future<void> loadChats() async {
    if (authProvider.apiService == null) {
      _error = 'API сервис недоступен';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final chats = await authProvider.apiService!.getChats();
      _chats = chats;
      _chats.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.updatedAt;
        final bTime = b.lastMessageAt ?? b.updatedAt;
        return bTime.compareTo(aTime);
      });
    } catch (e) {
      _error = 'Ошибка загрузки чатов: $e';
      print('ChatProvider loadChats error: $e');
      _chats = []; // Очищаем список при ошибке
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Chat?> createChat({
    required String type,
    required List<int> participantIds,
    String? name,
  }) async {
    _lastError = null;
    
    if (authProvider.apiService == null) {
      _lastError = 'Сервис API недоступен';
      return null;
    }

    try {
      final chat = await authProvider.apiService!.createChat(
        type: type,
        participantIds: participantIds,
        name: name,
      );

      if (chat != null) {
        _chats.insert(0, chat);
        notifyListeners();
      } else {
        _lastError = 'Не удалось создать чат.';
      }

      return chat;
    } catch (e) {
      _lastError = 'Ошибка создания чата: ${e.toString()}';
      return null;
    }
  }

  Future<Chat?> getChatById(int id) async {
    if (authProvider.apiService == null) return null;

    try {
      return await authProvider.apiService!.getChatById(id);
    } catch (e) {
      return null;
    }
  }

  void _updateChatFromSocket(int chatId, Map<String, dynamic> data) {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      try {
        _chats[index] = Chat.fromJson(data);
        _chats.sort((a, b) {
          final aTime = a.lastMessageAt ?? a.updatedAt;
          final bTime = b.lastMessageAt ?? b.updatedAt;
          return bTime.compareTo(aTime);
        });
        notifyListeners();
      } catch (e) {
        // Ignore parsing errors
      }
    } else {
      // Новый чат
      try {
        final chat = Chat.fromJson(data);
        _chats.insert(0, chat);
        notifyListeners();
      } catch (e) {
        // Ignore parsing errors
      }
    }
  }

  void updateChatLastMessage(int chatId, String? message, User? sender, DateTime? time) {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      _chats[index] = Chat(
        id: _chats[index].id,
        type: _chats[index].type,
        name: _chats[index].name,
        avatar: _chats[index].avatar,
        participants: _chats[index].participants,
        lastMessageSender: sender,
        lastMessage: message,
        lastMessageAt: time,
        unreadCount: _chats[index].unreadCount,
        createdAt: _chats[index].createdAt,
        updatedAt: _chats[index].updatedAt,
      );
      _chats.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.updatedAt;
        final bTime = b.lastMessageAt ?? b.updatedAt;
        return bTime.compareTo(aTime);
      });
      notifyListeners();
    }
  }

  void incrementUnreadCount(int chatId) {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      _chats[index] = Chat(
        id: _chats[index].id,
        type: _chats[index].type,
        name: _chats[index].name,
        avatar: _chats[index].avatar,
        participants: _chats[index].participants,
        lastMessageSender: _chats[index].lastMessageSender,
        lastMessage: _chats[index].lastMessage,
        lastMessageAt: _chats[index].lastMessageAt,
        unreadCount: _chats[index].unreadCount + 1,
        createdAt: _chats[index].createdAt,
        updatedAt: _chats[index].updatedAt,
      );
      notifyListeners();
    }
  }

  void clearUnreadCount(int chatId) {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      _chats[index] = Chat(
        id: _chats[index].id,
        type: _chats[index].type,
        name: _chats[index].name,
        avatar: _chats[index].avatar,
        participants: _chats[index].participants,
        lastMessageSender: _chats[index].lastMessageSender,
        lastMessage: _chats[index].lastMessage,
        lastMessageAt: _chats[index].lastMessageAt,
        unreadCount: 0,
        createdAt: _chats[index].createdAt,
        updatedAt: _chats[index].updatedAt,
      );
      notifyListeners();
    }
  }
}

