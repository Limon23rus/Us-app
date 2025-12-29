import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/message_cache_service.dart';

class MessageProvider extends ChangeNotifier {
  final AuthProvider authProvider;
  ChatProvider? _chatProvider;
  final MessageCacheService _cacheService = MessageCacheService();
  
  final Map<int, List<Message>> _messages = {};
  final Map<int, bool> _isTyping = {};
  final Map<int, bool> _isLoading = {};
  final Map<int, bool> _hasMore = {};
  final Map<int, int> _page = {};
  final Map<int, DateTime?> _oldestMessageTime = {}; // Время самого старого сообщения для пагинации

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
      } catch (e) {
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
      _oldestMessageTime[chatId] = null;
      
      // При первой загрузке сначала загружаем из кэша
      try {
        final cachedMessages = await _cacheService.getLastCachedMessages(chatId, 1000);
        if (cachedMessages.isNotEmpty) {
          _messages[chatId] = cachedMessages;
          notifyListeners();
          
          // Устанавливаем время самого старого сообщения для пагинации
          if (cachedMessages.isNotEmpty) {
            _oldestMessageTime[chatId] = cachedMessages.first.createdAt;
          }
        }
      } catch (e) {
        // Ошибка загрузки из кэша, продолжаем
      }
    }

    if (!hasMore(chatId) && !refresh) return;

    _isLoading[chatId] = true;
    notifyListeners();

    try {
      int limit;
      int offset;
      
      if (refresh) {
        // При первой загрузке загружаем последние 1000 сообщений
        // Бэкенд возвращает сообщения от старых к новым после reverse()
        // offset=0 вернет первые 1000 сообщений (самые старые)
        // Для получения последних нужно использовать большой offset или другой подход
        // Пока используем offset=0 и limit=1000 для получения первых 1000
        limit = 1000;
        offset = 0;
      } else {
        // При подгрузке старых сообщений загружаем по 50 за раз
        limit = 50;
        // Увеличиваем offset для загрузки более старых сообщений
        final currentPage = _page[chatId] ?? 0;
        offset = currentPage * limit;
      }

      final messages = await authProvider.apiService!.getMessages(
        chatId,
        limit: limit,
        offset: offset,
      );

      if (messages.isEmpty) {
        _hasMore[chatId] = false;
        _isLoading[chatId] = false;
        notifyListeners();
        return;
      }

      if (refresh) {
        // При первой загрузке: бэкенд уже возвращает сообщения от старых к новым
        // Объединяем с кэшированными сообщениями, если они есть
        final existing = _messages[chatId] ?? [];
        final existingIds = existing.map((m) => m.id).toSet();
        final newMessages = messages.where((m) => !existingIds.contains(m.id)).toList();
        
        // Объединяем все сообщения и сортируем по времени
        final allMessages = [...existing, ...newMessages];
        allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        
        if (newMessages.isNotEmpty || existing.isNotEmpty) {
          _messages[chatId] = allMessages;
          
          // Сохраняем новые сообщения в кэш
          if (newMessages.isNotEmpty) {
            await _cacheService.saveMessages(chatId, newMessages);
          }
        }
        
        // Устанавливаем время самого старого сообщения для пагинации
        if (allMessages.isNotEmpty) {
          _oldestMessageTime[chatId] = allMessages.first.createdAt;
        }
      } else {
        // При подгрузке старых сообщений: добавляем в начало списка
        final existing = _messages[chatId] ?? [];
        final existingIds = existing.map((m) => m.id).toSet();
        // API возвращает от старых к новым, поэтому не переворачиваем
        final newMessages = messages.where((m) => !existingIds.contains(m.id)).toList();
        
        if (newMessages.isNotEmpty) {
          // Старые сообщения добавляем в начало
          _messages[chatId] = [...newMessages, ...existing];
          
          // Сохраняем новые сообщения в кэш
          await _cacheService.saveMessages(chatId, newMessages);
          
          // Обновляем время самого старого сообщения
          _oldestMessageTime[chatId] = newMessages.first.createdAt;
        }
      }

      // Если получили меньше сообщений, чем запросили, значит больше нет
      _hasMore[chatId] = messages.length == limit;
      _page[chatId] = (_page[chatId] ?? 0) + 1;
    } catch (e) {
      // Обрабатываем ошибки
      _hasMore[chatId] = false;
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

  void _addMessage(int chatId, Message message) async {
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
      
      // Сохраняем в кэш
      try {
        await _cacheService.addMessage(message);
      } catch (e) {
        // Ошибка сохранения в кэш, игнорируем
      }
      
      notifyListeners();
    } else {
      // Сообщение уже есть, обновляем его (на случай если пришла обновленная версия)
      _messages[chatId]![existingIndex] = message;
      
      // Обновляем в кэше
      try {
        await _cacheService.updateMessage(message);
      } catch (e) {
        // Ошибка обновления в кэше, игнорируем
      }
      
      notifyListeners();
    }
  }

  void _markMessagesAsRead(int chatId, List<int> messageIds) async {
    if (_messages[chatId] == null) return;

    for (var i = 0; i < _messages[chatId]!.length; i++) {
      if (messageIds.contains(_messages[chatId]![i].id)) {
        final updatedMessage = Message(
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
        _messages[chatId]![i] = updatedMessage;
        
        // Обновляем в кэше
        try {
          await _cacheService.updateMessage(updatedMessage);
        } catch (e) {
          // Ошибка обновления в кэше, игнорируем
        }
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
    _oldestMessageTime.remove(chatId);
    notifyListeners();
  }
  
  /// Очищает кэш для указанного чата
  Future<void> clearCache(int chatId) async {
    try {
      await _cacheService.clearCacheForChat(chatId);
    } catch (e) {
      // Ошибка очистки кэша, игнорируем
    }
  }
}
