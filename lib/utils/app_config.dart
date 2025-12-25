class AppConfig {
  // Измените на ваш сервер
  static const String baseUrl = 'http://141.105.67.237';
  static const String apiUrl = '$baseUrl/api';
  static const String socketUrl = baseUrl;
  
  // Endpoints
  static const String registerEndpoint = '$apiUrl/auth/register';
  static const String loginEndpoint = '$apiUrl/auth/login';
  static const String verifyEndpoint = '$apiUrl/auth/verify';
  static const String usersMeEndpoint = '$apiUrl/users/me';
  static const String usersSearchEndpoint = '$apiUrl/users/search';
  static const String chatsEndpoint = '$apiUrl/chats';
  static const String messagesEndpoint = '$apiUrl/messages';
  static const String uploadEndpoint = '$apiUrl/upload';
}

