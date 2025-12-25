import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class MessageProvider extends ChangeNotifier {
  final AuthProvider authProvider;
  ChatProvider? _chatProvider;
  
  final Map<int, List<Message>> _messages = {};
  final Map<int, bool> _isTyping = {};
  final Map<int, bool> _isLoading = {};
  final Map<int, bool> _hasMore = {};
  final Map<int, int> _page = {};

  MessageProvider({required this.authProvider}) {
    _setupSocketListeners();
  }

  void setChatProvider(ChatProvider chatProvider) {
    _chatProvider = chatProvider;
  }

  List<Message> getMessages(int chatId) {
    final messages = _messages[chatId] ?? [];
    // Сортируем по времени создания (старые первыми)
    final sorted = List<Message>.from(messages);
    sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  bool isTyping(int chatId) {
    return _isTyping[chatId] ?? false;
  }

  bool isLoading(int chatId) {
    return _isLoading[chatId] ?? false;
  }

  bool hasMore(int chatId) {
    return _hasMore[chatId] ?? true;
  }

  void _setupSocketListeners() {
    final socketService = authProvider.socketService;
    if (socketService == null) return;

    socketService.onMessageNew((message) {
      try {
        // Добавляем сообщение
        _addMessage(message.chatId, message);
        
        // Обновляем последнее сообщение в чате
        _chatProvider?.updateChatLastMessage(
          message.chatId,
          message.content,
          message.sender,
          message.createdAt,
        );
        
        // Увеличиваем счетчик непрочитанных только для сообщений от других пользователей
        if (authProvider.user != null && message.sender.id != authProvider.user!.id) {
          _chatProvider?.incrementUnreadCount(message.chatId);
        }
      } catch (e, stackTrace) {
        // Ошибка обработки сообщения
      }
    });

    socketService.onMessagesRead((data) {
      final chatId = data['chatId'] as int?;
      final messageIds = data['messageIds'] as List<dynamic>?;
      if (chatId != null && messageIds != null) {
        _markMessagesAsRead(chatId, messageIds.cast<int>());
      }
    });

    socketService.onTypingStart((data) {
      final chatId = data['chatId'] as int?;
      final userId = data['userId'] as int?;
      if (chatId != null && userId != authProvider.user?.id) {
        _isTyping[chatId] = true;
        notifyListeners();
      }
    });

    socketService.onTypingStop((data) {
      final chatId = data['chatId'] as int?;
      if (chatId != null) {
        _isTyping[chatId] = false;
        notifyListeners();
      }
    });
  }

  Future<void> loadMessages(int chatId, {bool refresh = false}) async {
    if (authProvider.apiService == null) return;

    if (refresh) {
      _page[chatId] = 0;
      _hasMore[chatId] = true;
      _messages[chatId] = []; // Очищаем сообщения при обновлении
    }

    if (!hasMore(chatId) && !refresh) return;

    _isLoading[chatId] = true;
    notifyListeners();

    try {
      final page = _page[chatId] ?? 0;
      final limit = 1000;
      final offset = page * limit;

      final messages = await authProvider.apiService!.getMessages(
        chatId,
        limit: limit,
        offset: offset,
      );

      if (refresh) {
        // При первой загрузке: загружаем последние 1000 сообщений
        _messages[chatId] = messages.reversed.toList();
      } else {
        // При подгрузке старых сообщений: добавляем в начало списка
        final existing = _messages[chatId] ?? [];
        final existingIds = existing.map((m) => m.id).toSet();
        final newMessages = messages.reversed.where((m) => !existingIds.contains(m.id)).toList();
        // Старые сообщения добавляем в начало
        _messages[chatId] = [...newMessages, ...existing];
      }

      // Если получили меньше сообщений, чем запросили, значит больше нет
      _hasMore[chatId] = messages.length == limit;
      _page[chatId] = (page + 1);
    } catch (e) {
      // Handle error
    }

    _isLoading[chatId] = false;
    notifyListeners();
  }

  // Метод для загрузки старых сообщений (при прокрутке вверх)
  Future<void> loadMoreMessages(int chatId) async {
    if (_isLoading[chatId] == true || !hasMore(chatId)) return;
    await loadMessages(chatId, refresh: false);
  }

  Future<Message?> sendMessage({
    required int chatId,
    required String content,
    required String messageType,
    String? fileUrl,
    String? fileName,
  }) async {
    if (authProvider.apiService == null) return null;

    final currentUser = authProvider.user;
    if (currentUser == null) return null;

    // Отправляем ТОЛЬКО через HTTP API
    // HTTP API сам отправит событие через Socket.io для real-time уведомлений
    try {
      final message = await authProvider.apiService!.sendMessage(
        chatId: chatId,
        content: content,
        messageType: messageType,
        fileUrl: fileUrl,
        fileName: fileName,
      );
      
      // Сообщение придет через WebSocket, поэтому не добавляем его здесь
      // Это предотвращает дублирование
      return message;
    } catch (e) {
      return null;
    }
  }

  void _addMessage(int chatId, Message message) {
    if (_messages[chatId] == null) {
      _messages[chatId] = [];
    }
    
    // Проверяем, нет ли уже такого сообщения по ID
    final existingIndex = _messages[chatId]!.indexWhere((m) => m.id == message.id && m.id != 0);
    
    if (existingIndex == -1) {
      // Также проверяем по содержимому и времени (на случай если ID еще не присвоен или дубликат)
      final similarMessageIndex = _messages[chatId]!.indexWhere(
        (m) => m.content == message.content &&
               m.sender.id == message.sender.id &&
               (m.createdAt.difference(message.createdAt).inSeconds.abs() < 3),
      );
      
      // Если нашли похожее сообщение, не добавляем
      if (similarMessageIndex != -1) {
        return;
      }
      
      // Сообщения нет, добавляем
      _messages[chatId]!.add(message);
      notifyListeners();
    } else {
      // Сообщение уже есть, обновляем его (на случай если пришла обновленная версия)
      _messages[chatId]![existingIndex] = message;
      notifyListeners();
    }
  }

  void _markMessagesAsRead(int chatId, List<int> messageIds) {
    if (_messages[chatId] == null) return;

    for (var i = 0; i < _messages[chatId]!.length; i++) {
      if (messageIds.contains(_messages[chatId]![i].id)) {
        _messages[chatId]![i] = Message(
          id: _messages[chatId]![i].id,
          chatId: _messages[chatId]![i].chatId,
          sender: _messages[chatId]![i].sender,
          content: _messages[chatId]![i].content,
          messageType: _messages[chatId]![i].messageType,
          fileUrl: _messages[chatId]![i].fileUrl,
          fileName: _messages[chatId]![i].fileName,
          isRead: true,
          createdAt: _messages[chatId]![i].createdAt,
          updatedAt: _messages[chatId]![i].updatedAt,
        );
      }
    }
    notifyListeners();
  }

  Future<void> markAsRead(int chatId) async {
    if (authProvider.apiService == null) return;

    await authProvider.apiService!.markMessagesAsRead(chatId);
    _chatProvider?.clearUnreadCount(chatId);

    // Также через Socket
    authProvider.socketService?.markMessagesAsRead(chatId);
  }

  void startTyping(int chatId) {
    authProvider.socketService?.startTyping(chatId);
  }

  void stopTyping(int chatId) {
    authProvider.socketService?.stopTyping(chatId);
  }

  void clearMessages(int chatId) {
    _messages.remove(chatId);
    _isTyping.remove(chatId);
    _isLoading.remove(chatId);
    _hasMore.remove(chatId);
    _page.remove(chatId);
    notifyListeners();
  }
}
