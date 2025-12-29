import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/message_provider.dart';
import '../../models/chat.dart';
import '../../models/user.dart';
import 'chat_screen.dart';
import '../search/search_users_screen.dart';
import '../profile/profile_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChats();
      _linkProviders();
    });
  }

  void _linkProviders() {
    final messageProvider = Provider.of<MessageProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    messageProvider.setChatProvider(chatProvider);
  }

  Future<void> _loadChats() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // Проверяем, что пользователь авторизован
    if (!authProvider.isAuthenticated || authProvider.user == null) {
      print('User not authenticated, cannot load chats');
      return;
    }
    
    // Проверяем, что API сервис доступен
    if (authProvider.apiService == null) {
      print('API service not available');
      return;
    }
    
    await chatProvider.loadChats();
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Вчера';
    } else if (difference.inDays < 7) {
      // Используем номер дня недели вместо локализованного названия
      final weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      final weekdayIndex = dateTime.weekday - 1;
      return weekdays[weekdayIndex];
    } else {
      return DateFormat('dd.MM.yyyy').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SearchUsersScreen(),
                ),
              );
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Профиль'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProfileScreen(),
                    ),
                  );
                },
              ),
              PopupMenuItem(
                child: const Text('Выйти'),
                onTap: () async {
                  await authProvider.logout();
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadChats,
        child: chatProvider.isLoading && chatProvider.chats.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : chatProvider.error != null && chatProvider.chats.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ошибка загрузки',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            chatProvider.error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadChats,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  )
            : chatProvider.chats.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Нет чатов',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Начните новый чат',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: chatProvider.chats.length,
                    itemBuilder: (context, index) {
                      final chat = chatProvider.chats[index];
                      final currentUser = authProvider.user;
                      if (currentUser == null) return const SizedBox();

                      return ChatListItem(
                        chat: chat,
                        currentUser: currentUser,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(chat: chat),
                            ),
                          );
                        },
                        formatTime: _formatTime,
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SearchUsersScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ChatListItem extends StatelessWidget {
  final Chat chat;
  final User currentUser;
  final VoidCallback onTap;
  final String Function(DateTime?) formatTime;

  const ChatListItem({
    super.key,
    required this.chat,
    required this.currentUser,
    required this.onTap,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = chat.getDisplayName(currentUser);
    final displayAvatar = chat.getDisplayAvatar(currentUser);
    final lastMessageTime = formatTime(chat.lastMessageAt);
    final isGroup = chat.type == ChatType.group;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: displayAvatar != null
            ? NetworkImage(displayAvatar)
            : null,
        child: displayAvatar == null
            ? Text(displayName[0].toUpperCase())
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (isGroup)
            Icon(
              Icons.group,
              size: 16,
              color: Colors.grey[600],
            ),
        ],
      ),
      subtitle: Text(
        chat.lastMessage ?? 'Нет сообщений',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lastMessageTime.isNotEmpty)
            Text(
              lastMessageTime,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          if (chat.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                chat.unreadCount > 99 ? '99+' : chat.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}

