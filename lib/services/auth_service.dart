import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../utils/app_config.dart';

class AuthService {
  final SharedPreferences prefs;
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  AuthService({required this.prefs});

  String? get token => prefs.getString(_tokenKey);

  Future<void> saveToken(String token) async {
    await prefs.setString(_tokenKey, token);
  }

  Future<void> saveUser(User user) async {
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  User? getCurrentUser() {
    final userJson = prefs.getString(_userKey);
    if (userJson == null) return null;
    return User.fromJson(jsonDecode(userJson));
  }

  Future<void> clearAuth() async {
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Map<String, String> getAuthHeaders() {
    final token = this.token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.registerEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          
          // Проверяем разные форматы ответа
          String? token;
          Map<String, dynamic>? userData;
          
          if (data.containsKey('token') && data['token'] != null) {
            final tokenValue = data['token'];
            token = tokenValue is String ? tokenValue : tokenValue.toString();
          }
          
          if (data.containsKey('user') && data['user'] != null) {
            final userValue = data['user'];
            if (userValue is Map<String, dynamic>) {
              userData = userValue;
            }
          } else if (data.containsKey('id')) {
            // Возможно, весь объект - это user
            userData = data;
          }
          
          if (token == null || token.isEmpty) {
            return {
              'success': false,
              'error': 'Токен не получен от сервера. Проверьте структуру ответа.',
            };
          }
          
          if (userData == null) {
            return {
              'success': false,
              'error': 'Данные пользователя не получены от сервера.',
            };
          }
          
          final user = User.fromJson(userData);
          
          await saveToken(token);
          await saveUser(user);

          return {'success': true, 'user': user, 'token': token};
        } catch (e, stackTrace) {
          return {
            'success': false,
            'error': 'Ошибка обработки ответа сервера: $e',
          };
        }
      } else {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          String errorMessage = 'Ошибка регистрации';
          
          if (data.containsKey('message')) {
            errorMessage = data['message'] as String;
          } else if (data.containsKey('error')) {
            errorMessage = data['error'] as String;
          } else if (data.containsKey('errors')) {
            final errors = data['errors'];
            if (errors is List) {
              errorMessage = errors.join(', ');
            } else if (errors is Map) {
              errorMessage = errors.values.join(', ');
            }
          }
          
          return {
            'success': false,
            'error': errorMessage,
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Ошибка сервера (${response.statusCode}): ${response.body}',
          };
        }
      }
    } catch (e, stackTrace) {
      return {
        'success': false,
        'error': 'Ошибка подключения: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.loginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          
          // Проверяем разные форматы ответа
          String? token;
          Map<String, dynamic>? userData;
          
          if (data.containsKey('token') && data['token'] != null) {
            final tokenValue = data['token'];
            token = tokenValue is String ? tokenValue : tokenValue.toString();
          }
          
          if (data.containsKey('user') && data['user'] != null) {
            final userValue = data['user'];
            if (userValue is Map<String, dynamic>) {
              userData = userValue;
            }
          } else if (data.containsKey('id')) {
            // Возможно, весь объект - это user
            userData = data;
          }
          
          if (token == null || token.isEmpty) {
            return {
              'success': false,
              'error': 'Токен не получен от сервера. Проверьте структуру ответа.',
            };
          }
          
          if (userData == null) {
            return {
              'success': false,
              'error': 'Данные пользователя не получены от сервера.',
            };
          }
          
          final user = User.fromJson(userData);
          
          await saveToken(token);
          await saveUser(user);

          return {'success': true, 'user': user, 'token': token};
        } catch (e, stackTrace) {
          return {
            'success': false,
            'error': 'Ошибка обработки ответа сервера: $e',
          };
        }
      } else {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          String errorMessage = 'Ошибка входа';
          
          if (data.containsKey('message')) {
            errorMessage = data['message'] as String? ?? errorMessage;
          } else if (data.containsKey('error')) {
            errorMessage = data['error'] as String? ?? errorMessage;
          } else if (data.containsKey('errors')) {
            final errors = data['errors'];
            if (errors is List) {
              errorMessage = errors.join(', ');
            } else if (errors is Map) {
              errorMessage = errors.values.join(', ');
            }
          }
          
          return {
            'success': false,
            'error': errorMessage,
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Ошибка сервера (${response.statusCode}): ${response.body}',
          };
        }
      }
    } catch (e, stackTrace) {
      return {
        'success': false,
        'error': 'Ошибка подключения: ${e.toString()}',
      };
    }
  }

  Future<bool> verifyToken() async {
    if (token == null) return false;

    try {
      final response = await http.get(
        Uri.parse(AppConfig.verifyEndpoint),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final user = User.fromJson(data['user'] as Map<String, dynamic>);
        await saveUser(user);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<User?> getCurrentUserFromServer() async {
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse(AppConfig.usersMeEndpoint),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final user = User.fromJson(data as Map<String, dynamic>);
        await saveUser(user);
        return user;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

