import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService authService;
  final SharedPreferences prefs;
  
  User? _user;
  bool _isLoading = false;
  String? _error;
  SocketService? _socketService;
  ApiService? _apiService;

  AuthProvider({
    required this.authService,
    required this.prefs,
  }) {
    _apiService = ApiService(authService: authService);
    _socketService = SocketService(authService: authService);
    _loadUser();
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  SocketService? get socketService => _socketService;
  ApiService? get apiService => _apiService;

  Future<void> _loadUser() async {
    _user = authService.getCurrentUser();
    if (_user != null) {
      await verifyToken();
    }
    notifyListeners();
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await authService.register(
      username: username,
      email: email,
      password: password,
    );

    _isLoading = false;

    if (result['success'] == true) {
      _user = result['user'] as User;
      _socketService?.connect();
      notifyListeners();
      return true;
    } else {
      _error = result['error'] as String;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await authService.login(
      email: email,
      password: password,
    );

    _isLoading = false;

    if (result['success'] == true) {
      _user = result['user'] as User;
      _socketService?.connect();
      notifyListeners();
      return true;
    } else {
      _error = result['error'] as String;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyToken() async {
    final isValid = await authService.verifyToken();
    if (isValid) {
      _user = authService.getCurrentUser();
      if (_user != null && !(_socketService?.isConnected ?? false)) {
        _socketService?.connect();
      }
    } else {
      await logout();
    }
    notifyListeners();
    return isValid;
  }

  Future<void> logout() async {
    _socketService?.disconnect();
    await authService.clearAuth();
    _user = null;
    _error = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    final user = await authService.getCurrentUserFromServer();
    if (user != null) {
      _user = user;
      notifyListeners();
    }
  }
}

