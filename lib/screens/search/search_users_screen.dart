import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/user.dart';
import '../../models/chat.dart';
import '../../services/api_service.dart';
import '../chats/chat_screen.dart';
import 'create_group_screen.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final _searchController = TextEditingController();
  ApiService? _apiService;
  List<User> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _apiService = authProvider.apiService;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty || _apiService == null) {
      setState(() {
        _users = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final users = await _apiService!.searchUsers(query);
    
    if (mounted) {
      setState(() {
        _users = users;
        _isLoading = false;
      });
    }
  }

  Future<void> _createChat(User user) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentUser = authProvider.user;

    if (currentUser == null) return;

    // Проверяем, есть ли уже чат с этим пользователем
    Chat? existingChat;
    try {
      existingChat = chatProvider.chats.firstWhere(
        (chat) =>
            chat.type.toString().contains('private') &&
            chat.participants.any((p) => p.id == user.id),
      );
    } catch (e) {
      existingChat = null;
    }

    Chat? chat;
    if (existingChat == null) {
      // Создаем новый чат
      chat = await chatProvider.createChat(
        type: 'private',
        participantIds: [user.id],
      );
    } else {
      chat = existingChat;
    }

    if (chat != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(chat: chat!),
        ),
      );
    } else if (mounted) {
      // Показываем более детальное сообщение об ошибке
      String errorMessage = chatProvider.lastError ?? 'Не удалось создать чат';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Повторить',
            textColor: Colors.white,
            onPressed: () => _createChat(user),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск пользователей'),
      ),
      body: Column(
        children: [
          // Кнопка создания группы
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateGroupScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.group_add),
                label: const Text('Создать группу'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск по имени или email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _searchUsers,
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_users.isEmpty && _searchController.text.isNotEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Пользователи не найдены',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          else if (_users.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Начните поиск',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  // Пропускаем текущего пользователя
                  if (currentUser != null && user.id == currentUser.id) {
                    return const SizedBox();
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user.avatar != null
                          ? NetworkImage(user.avatar!)
                          : null,
                      child: user.avatar == null
                          ? Text(user.username[0].toUpperCase())
                          : null,
                    ),
                    title: Text(user.username),
                    subtitle: Text(user.email),
                    trailing: Icon(
                      Icons.chat_bubble_outline,
                      color: Theme.of(context).primaryColor,
                    ),
                    onTap: () => _createChat(user),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

