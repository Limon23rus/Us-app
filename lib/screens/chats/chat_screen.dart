import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import '../../models/chat.dart';
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
  final _imagePicker = ImagePicker();
  bool _isTyping = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Добавляем слушатель прокрутки для подгрузки старых сообщений
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
      _joinChat();
    });
  }

  void _onScroll() {
    // Если прокрутили близко к началу (верх списка), загружаем старые сообщения
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      // Если прокрутили вверх (близко к началу списка)
      if (position.pixels < 300 && position.pixels >= 0) {
        final messageProvider = Provider.of<MessageProvider>(context, listen: false);
        if (messageProvider.hasMore(widget.chat.id) && 
            !messageProvider.isLoading(widget.chat.id)) {
          // Сохраняем текущую позицию прокрутки
          final currentScrollPosition = position.pixels;
          final currentMaxScroll = position.maxScrollExtent;
          
          messageProvider.loadMoreMessages(widget.chat.id).then((_) {
            // После загрузки восстанавливаем позицию
            if (_scrollController.hasClients) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final newMaxScroll = _scrollController.position.maxScrollExtent;
                final scrollDifference = newMaxScroll - currentMaxScroll;
                _scrollController.jumpTo(currentScrollPosition + scrollDifference);
              });
            }
          });
        }
      }
    }
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        await _sendMedia(image.path, 'image', image.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выбора изображения: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 10),
      );

      if (video != null) {
        await _sendMedia(video.path, 'video', video.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выбора видео: $e')),
        );
      }
    }
  }

  Future<void> _sendMedia(String filePath, String messageType, String fileName) async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final messageProvider = Provider.of<MessageProvider>(context, listen: false);

      if (authProvider.apiService == null) {
        throw Exception('API сервис недоступен');
      }

      // Загружаем файл на сервер
      final fileUrl = await authProvider.apiService!.uploadFile(filePath, fileName);
      
      if (fileUrl == null) {
        throw Exception('Ошибка загрузки файла');
      }

      // Отправляем сообщение с медиа
      await messageProvider.sendMessage(
        chatId: widget.chat.id,
        content: messageType == 'image' ? 'Фото' : 'Видео',
        messageType: messageType,
        fileUrl: fileUrl,
        fileName: fileName,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Выбрать фото из галереи'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Сделать фото'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Выбрать видео из галереи'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Записать видео'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
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
                  reverse: false, // Сообщения от старых к новым (сверху вниз)
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length + 
                            (messageProvider.isLoading(widget.chat.id) ? 1 : 0) + 
                            (isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Индикатор загрузки старых сообщений (в начале списка)
                    if (messageProvider.isLoading(widget.chat.id) && index == 0) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    
                    // Индекс сообщения (учитываем индикатор загрузки)
                    final messageIndex = messageProvider.isLoading(widget.chat.id) ? index - 1 : index;
                    
                    // Индикатор печати (в конце списка)
                    if (isTyping && messageIndex == messages.length) {
                      return const TypingIndicator();
                    }

                    if (messageIndex < 0 || messageIndex >= messages.length) {
                      return const SizedBox.shrink();
                    }

                    final message = messages[messageIndex];
                    final isMe = message.sender.id == currentUser.id;
                    final showAvatar = messageIndex == 0 ||
                        messages[messageIndex - 1].sender.id != message.sender.id;

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
                IconButton(
                  icon: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file),
                  onPressed: _isUploading ? null : _showMediaPicker,
                  color: Theme.of(context).primaryColor,
                ),
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

