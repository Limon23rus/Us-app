import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/chat.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  final Chat chat;

  const ChatScreen({super.key, required this.chat});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
      _joinChat();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _stopTyping();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final messageProvider =
        Provider.of<MessageProvider>(context, listen: false);
    await messageProvider.loadMessages(widget.chat.id, refresh: true);
    _scrollToBottom();
  }

  void _joinChat() {
    final socketService =
        Provider.of<AuthProvider>(context, listen: false).socketService;
    socketService?.joinChat(widget.chat.id);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _startTyping() {
    if (!_isTyping) {
      _isTyping = true;
      final messageProvider =
          Provider.of<MessageProvider>(context, listen: false);
      messageProvider.startTyping(widget.chat.id);
    }
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      final messageProvider =
          Provider.of<MessageProvider>(context, listen: false);
      messageProvider.stopTyping(widget.chat.id);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _stopTyping();
    _messageController.clear();

    final messageProvider =
        Provider.of<MessageProvider>(context, listen: false);
    await messageProvider.sendMessage(
      chatId: widget.chat.id,
      content: text,
      messageType: 'text',
    );

    _scrollToBottom();
  }

  Future<void> _markAsRead() async {
    final messageProvider =
        Provider.of<MessageProvider>(context, listen: false);
    await messageProvider.markAsRead(widget.chat.id);
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return 'Сегодня';
    }
    return DateFormat('dd.MM.yyyy').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final messageProvider = Provider.of<MessageProvider>(context);
    final currentUser = authProvider.user;
    if (currentUser == null) return const Scaffold();

    final displayName = widget.chat.getDisplayName(currentUser);
    final isTyping = messageProvider.isTyping(widget.chat.id);

    // Отмечаем сообщения как прочитанные при открытии
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsRead();
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.chat.getDisplayAvatar(currentUser) != null
                  ? NetworkImage(widget.chat.getDisplayAvatar(currentUser)!)
                  : null,
              child: widget.chat.getDisplayAvatar(currentUser) == null
                  ? Text(displayName[0].toUpperCase())
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName),
                  if (isTyping)
                    Text(
                      'печатает...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<MessageProvider>(
              builder: (context, messageProvider, _) {
                final messages = messageProvider.getMessages(widget.chat.id);
                final isTyping = messageProvider.isTyping(widget.chat.id);
                
                // Автоматически прокручиваем вниз при новом сообщении
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });
                
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Нет сообщений'),
                  );
                }
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length + (isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (isTyping && index == messages.length) {
                      return const TypingIndicator();
                    }

                    final message = messages[index];
                    final isMe = message.sender.id == currentUser.id;
                    final showAvatar = index == 0 ||
                        messages[index - 1].sender.id != message.sender.id;

                    return MessageBubble(
                      message: message,
                      isMe: isMe,
                      showAvatar: showAvatar,
                      formatTime: _formatTime,
                      formatDate: _formatDate,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Введите сообщение...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (text) {
                      if (text.isNotEmpty) {
                        _startTyping();
                      } else {
                        _stopTyping();
                      }
                    },
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

