import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../utils/app_config.dart';

class ApiService {
  final AuthService authService;

  ApiService({required this.authService});

  Map<String, String> getHeaders() {
    return authService.getAuthHeaders();
  }

  // Users
  Future<List<User>> searchUsers(String query) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.usersSearchEndpoint}?q=$query'),
        headers: getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.map((json) => User.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<User?> getUserById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/users/$id'),
        headers: getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return User.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Chats
  Future<List<Chat>> getChats() async {
    try {
      final headers = getHeaders();
      print('Get chats: ${AppConfig.chatsEndpoint}');
      print('Headers: ${headers.containsKey('Authorization') ? 'Token present' : 'No token'}');
      
      final response = await http.get(
        Uri.parse(AppConfig.chatsEndpoint),
        headers: headers,
      );

      print('Get chats response: ${response.statusCode}');
      print('Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        print('Parsed ${data.length} chats from response');
        
        final chats = data.map((json) {
          try {
            return Chat.fromJson(json as Map<String, dynamic>);
          } catch (e) {
            print('Error parsing chat: $e');
            print('Chat data: $json');
            return null;
          }
        }).whereType<Chat>().toList();
        
        print('Successfully parsed ${chats.length} chats');
        return chats;
      } else if (response.statusCode == 401) {
        print('Unauthorized - token may be invalid');
        throw Exception('Не авторизован. Пожалуйста, войдите снова.');
      } else if (response.statusCode == 403) {
        print('Forbidden');
        throw Exception('Доступ запрещен');
      } else {
        print('Get chats error: ${response.statusCode} - ${response.body}');
        throw Exception('Ошибка загрузки чатов: ${response.statusCode}');
      }
    } catch (e) {
      print('Get chats exception: $e');
      rethrow;
    }
  }

  Future<Chat?> getChatById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.chatsEndpoint}/$id'),
        headers: getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Chat.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Chat?> createChat({
    required String type,
    required List<int> participantIds,
    String? name,
  }) async {
    try {
      final requestBody = {
        'type': type,
        'participantIds': participantIds,
        if (name != null) 'name': name,
      };
      
      final response = await http.post(
        Uri.parse(AppConfig.chatsEndpoint),
        headers: getHeaders(),
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return Chat.fromJson(data);
        } catch (e) {
          return null;
        }
      } else {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          String errorMessage = 'Ошибка создания чата';
          
          if (data.containsKey('message')) {
            errorMessage = data['message'] as String? ?? errorMessage;
          } else if (data.containsKey('error')) {
            errorMessage = data['error'] as String? ?? errorMessage;
          }
          
          return null;
        } catch (e) {
          return null;
        }
      }
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateChat(int id, Map<String, dynamic> updates) async {
    try {
      final response = await http.patch(
        Uri.parse('${AppConfig.chatsEndpoint}/$id'),
        headers: getHeaders(),
        body: jsonEncode(updates),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Messages
  Future<List<Message>> getMessages(int chatId, {int? limit, int? offset}) async {
    try {
      String url = '${AppConfig.messagesEndpoint}/chat/$chatId';
      final params = <String>[];
      if (limit != null) params.add('limit=$limit');
      if (offset != null) params.add('offset=$offset');
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.map((json) {
          try {
            return Message.fromJson(json as Map<String, dynamic>);
          } catch (e) {
            // Логируем ошибку парсинга, но продолжаем обработку других сообщений
            return null;
          }
        }).whereType<Message>().toList();
      } else if (response.statusCode == 403) {
        throw Exception('Доступ запрещен к этому чату');
      } else if (response.statusCode == 404) {
        throw Exception('Чат не найден');
      } else {
        throw Exception('Ошибка загрузки сообщений: ${response.statusCode}');
      }
    } catch (e) {
      // Пробрасываем исключение дальше для обработки в провайдере
      rethrow;
    }
  }

  Future<Message?> sendMessage({
    required int chatId,
    required String content,
    required String messageType,
    String? fileUrl,
    String? fileName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.messagesEndpoint),
        headers: getHeaders(),
        body: jsonEncode({
          'chatId': chatId,
          'content': content,
          'messageType': messageType,
          if (fileUrl != null) 'fileUrl': fileUrl,
          if (fileName != null) 'fileName': fileName,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Message.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> markMessagesAsRead(int chatId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.messagesEndpoint}/chat/$chatId/read'),
        headers: getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Profile
  Future<User?> updateProfile({
    String? username,
    String? avatarUrl,
  }) async {
    try {
      final requestBody = <String, dynamic>{};
      if (username != null) requestBody['username'] = username;
      if (avatarUrl != null) requestBody['avatarUrl'] = avatarUrl;

      final response = await http.patch(
        Uri.parse(AppConfig.usersMeEndpoint),
        headers: getHeaders(),
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return User.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Upload
  Future<String?> uploadFile(String filePath, String fileName) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConfig.uploadEndpoint),
      );
      
      // Для multipart запросов добавляем только заголовки авторизации
      // Content-Type будет установлен автоматически с boundary
      final authHeaders = getHeaders();
      // Убираем Content-Type, если он есть, так как для multipart он устанавливается автоматически
      authHeaders.remove('Content-Type');
      request.headers.addAll(authHeaders);
      
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Бэкенд возвращает fileUrl в формате /uploads/filename
        final fileUrl = data['fileUrl'] as String?;
        if (fileUrl != null) {
          // Если URL относительный, добавляем baseUrl
          if (fileUrl.startsWith('/')) {
            return '${AppConfig.baseUrl}$fileUrl';
          }
          return fileUrl;
        }
        print('Upload response missing fileUrl: $data');
        return null;
      } else {
        // Логируем ошибку для отладки
        print('Upload error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      // Логируем ошибку для отладки
      print('Upload exception: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
}

