import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/message.dart';
import '../services/auth_service.dart';
import '../utils/app_config.dart';

class SocketService {
  IO.Socket? _socket;
  final AuthService authService;
  
  SocketService({required this.authService});

  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    if (_socket?.connected ?? false) return;

    final token = authService.token;
    if (token == null) return;

    _socket = IO.io(
      AppConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      // Socket connected
    });

    _socket!.onDisconnect((_) {
      // Socket disconnected
    });

    _socket!.onError((error) {
      // Socket error
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  // Listeners
  void onMessageNew(Function(Message) callback) {
    _socket?.on('message:new', (data) {
      try {
        if (data is Map<String, dynamic>) {
          callback(Message.fromJson(data));
        }
      } catch (e, stackTrace) {
        // Ошибка обработки сообщения
      }
    });
  }

  void onMessagesRead(Function(Map<String, dynamic>) callback) {
    _socket?.on('messages:read', (data) {
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

  void onTypingStart(Function(Map<String, dynamic>) callback) {
    _socket?.on('typing:start', (data) {
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

  void onTypingStop(Function(Map<String, dynamic>) callback) {
    _socket?.on('typing:stop', (data) {
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

  void onUserStatus(Function(Map<String, dynamic>) callback) {
    _socket?.on('user:status', (data) {
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

  void onChatUpdated(Function(Map<String, dynamic>) callback) {
    _socket?.on('chat:updated', (data) {
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

  void onChatJoined(Function(Map<String, dynamic>) callback) {
    _socket?.on('chat:joined', (data) {
      if (data is Map<String, dynamic>) {
        callback(data);
      }
    });
  }

  void onError(Function(String) callback) {
    _socket?.on('error', (data) {
      callback(data.toString());
    });
  }

  // Emitters
  void sendMessage(Map<String, dynamic> messageData) {
    _socket?.emit('message:send', messageData);
  }

  void markMessagesAsRead(int chatId) {
    _socket?.emit('messages:read', {'chatId': chatId});
  }

  void startTyping(int chatId) {
    _socket?.emit('typing:start', {'chatId': chatId});
  }

  void stopTyping(int chatId) {
    _socket?.emit('typing:stop', {'chatId': chatId});
  }

  void joinChat(int chatId) {
    _socket?.emit('chat:join', {'chatId': chatId});
  }

  void off(String event) {
    _socket?.off(event);
  }
}

