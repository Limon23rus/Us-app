import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../chats/chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();
  final List<User> _selectedParticipants = [];
  ApiService? _apiService;
  List<User> _searchResults = [];
  bool _isSearching = false;
  bool _isCreating = false;

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
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty || _apiService == null) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final users = await _apiService!.searchUsers(query);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.user;

    if (mounted) {
      setState(() {
        // Исключаем текущего пользователя и уже выбранных участников
        _searchResults = users.where((user) {
          if (currentUser != null && user.id == currentUser.id) return false;
          return !_selectedParticipants.any((p) => p.id == user.id);
        }).toList();
        _isSearching = false;
      });
    }
  }

  void _addParticipant(User user) {
    setState(() {
      if (!_selectedParticipants.any((p) => p.id == user.id)) {
        _selectedParticipants.add(user);
      }
      _searchController.clear();
      _searchResults = [];
    });
  }

  void _removeParticipant(User user) {
    setState(() {
      _selectedParticipants.removeWhere((p) => p.id == user.id);
    });
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите название группы'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы одного участника'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final participantIds = _selectedParticipants.map((p) => p.id).toList();

    final chat = await chatProvider.createChat(
      type: 'group',
      participantIds: participantIds,
      name: _groupNameController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isCreating = false;
      });

      if (chat != null) {
        // Переходим в созданный чат
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ChatScreen(chat: chat),
          ),
        );
      } else {
        final errorMessage = chatProvider.lastError ?? 'Не удалось создать группу';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создание группы'),
      ),
      body: Column(
        children: [
          // Поле ввода названия группы
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'Название группы',
                hintText: 'Введите название группы',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.group),
              ),
            ),
          ),

          // Список выбранных участников
          if (_selectedParticipants.isNotEmpty)
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Участники (${_selectedParticipants.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedParticipants.length,
                      itemBuilder: (context, index) {
                        final user = _selectedParticipants[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            avatar: CircleAvatar(
                              backgroundImage: user.avatar != null
                                  ? NetworkImage(user.avatar!)
                                  : null,
                              child: user.avatar == null
                                  ? Text(user.username[0].toUpperCase())
                                  : null,
                              radius: 12,
                            ),
                            label: Text(user.username),
                            onDeleted: () => _removeParticipant(user),
                            deleteIcon: const Icon(Icons.close, size: 18),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Поле поиска пользователей
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Поиск пользователей',
                hintText: 'Начните вводить имя или email...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: _searchUsers,
            ),
          ),

          // Список найденных пользователей
          if (_isSearching)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Пользователи не найдены',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          else if (_searchResults.isEmpty)
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
                      'Начните поиск участников',
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
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  final isSelected = _selectedParticipants.any((p) => p.id == user.id);

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
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.add_circle_outline),
                    onTap: () => _addParticipant(user),
                  );
                },
              ),
            ),

          // Кнопка создания группы
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isCreating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Создать',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

