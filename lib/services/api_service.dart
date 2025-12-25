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
      final response = await http.get(
        Uri.parse(AppConfig.chatsEndpoint),
        headers: getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        
        final chats = data.map((json) {
          try {
            return Chat.fromJson(json as Map<String, dynamic>);
          } catch (e) {
            return null;
          }
        }).whereType<Chat>().toList();
        
        return chats;
      }
      return [];
    } catch (e) {
      return [];
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
        } catch (e, stackTrace) {
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
    } catch (e, stackTrace) {
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
      if (limit != null || offset != null) {
        final params = <String>[];
        if (limit != null) params.add('limit=$limit');
        if (offset != null) params.add('offset=$offset');
        url += '?${params.join('&')}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.map((json) => Message.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
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

  // Upload
  Future<String?> uploadFile(String filePath, String fileName) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConfig.uploadEndpoint),
      );
      
      request.headers.addAll(getHeaders());
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['url'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

