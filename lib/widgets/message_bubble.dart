import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showAvatar;
  final String Function(DateTime) formatTime;
  final String Function(DateTime) formatDate;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.showAvatar,
    required this.formatTime,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final isText = message.messageType.toString().contains('text');
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar)
            CircleAvatar(
              radius: 16,
              backgroundImage: message.sender.avatar != null
                  ? NetworkImage(message.sender.avatar!)
                  : null,
              child: message.sender.avatar == null
                  ? Text(
                      message.sender.username[0].toUpperCase(),
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
            ),
          if (!isMe && showAvatar) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe
                    ? Theme.of(context).primaryColor
                    : Colors.grey[300],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.sender.username,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  if (isText)
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                      ),
                    )
                  else if (message.messageType.toString().contains('image'))
                    _buildImageMessage(context, message.fileUrl ?? '')
                  else if (message.messageType.toString().contains('video'))
                    _buildVideoMessage(context, message.fileUrl ?? '', message.fileName ?? 'Видео')
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.attach_file,
                          size: 16,
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            message.fileName ?? 'Файл',
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead
                              ? Icons.done_all
                              : Icons.done,
                          size: 12,
                          color: message.isRead
                              ? Colors.blue[200]
                              : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe && showAvatar) const SizedBox(width: 8),
          if (isMe && showAvatar)
            CircleAvatar(
              radius: 16,
              backgroundImage: message.sender.avatar != null
                  ? NetworkImage(message.sender.avatar!)
                  : null,
              child: message.sender.avatar == null
                  ? Text(
                      message.sender.username[0].toUpperCase(),
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _buildImageMessage(BuildContext context, String imageUrl) {
    return GestureDetector(
      onTap: () {
        // Открываем изображение в полноэкранном режиме
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.error,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 250,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 250,
            height: 200,
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 250,
            height: 200,
            color: Colors.grey[300],
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(height: 8),
                Text('Ошибка загрузки'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoMessage(BuildContext context, String videoUrl, String fileName) {
    return GestureDetector(
      onTap: () {
        // Открываем видео в полноэкранном режиме
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.black,
            child: Stack(
              children: [
                Center(
                  child: videoUrl.isNotEmpty
                      ? VideoPlayerWidget(videoUrl: videoUrl)
                      : const Text(
                          'Видео недоступно',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
        width: 250,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Превью видео (если есть)
            CachedNetworkImage(
              imageUrl: videoUrl.replaceAll(RegExp(r'\.(mp4|mov|avi)$'), '.jpg'),
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[900],
                child: const Icon(
                  Icons.videocam,
                  size: 64,
                  color: Colors.white54,
                ),
              ),
            ),
            // Затемнение для лучшей видимости кнопки
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            // Кнопка воспроизведения
            const Center(
              child: Icon(
                Icons.play_circle_filled,
                size: 64,
                color: Colors.white,
              ),
            ),
            // Название файла
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                fileName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 4,
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Простой виджет для воспроизведения видео
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  @override
  Widget build(BuildContext context) {
    // Для простоты используем встроенный проигрыватель
    // В продакшене лучше использовать video_player пакет
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.play_circle_filled,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            'Видео: ${widget.videoUrl}',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Открываем видео в браузере или внешнем приложении
              // В будущем можно интегрировать video_player
            },
            child: const Text('Открыть видео'),
          ),
        ],
      ),
    );
  }
}

