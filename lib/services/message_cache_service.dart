import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';
import '../models/user.dart';

class MessageCacheService {
  static const String _databaseName = 'messages_cache.db';
  static const String _tableName = 'messages';
  static const int _maxCachedMessages = 1000;
  static const int _version = 1;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY,
            chat_id INTEGER NOT NULL,
            sender_id INTEGER NOT NULL,
            sender_username TEXT NOT NULL,
            sender_email TEXT NOT NULL,
            sender_avatar TEXT,
            content TEXT NOT NULL,
            message_type TEXT NOT NULL,
            file_url TEXT,
            file_name TEXT,
            is_read INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            UNIQUE(id, chat_id)
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_chat_id_created_at ON $_tableName(chat_id, created_at)
        ''');
      },
    );
  }

  /// Сохраняет сообщения в кэш для указанного чата
  /// Автоматически ограничивает количество до _maxCachedMessages
  Future<void> saveMessages(int chatId, List<Message> messages) async {
    if (messages.isEmpty) return;

    final db = await database;
    final batch = db.batch();

    // Удаляем старые сообщения, если превышен лимит
    final existingCount = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM $_tableName WHERE chat_id = ?',
        [chatId],
      ),
    ) ?? 0;

    if (existingCount + messages.length > _maxCachedMessages) {
      // Удаляем самые старые сообщения
      final toDelete = existingCount + messages.length - _maxCachedMessages;
      await db.rawDelete('''
        DELETE FROM $_tableName 
        WHERE chat_id = ? 
        AND id IN (
          SELECT id FROM $_tableName 
          WHERE chat_id = ? 
          ORDER BY created_at ASC 
          LIMIT ?
        )
      ''', [chatId, chatId, toDelete]);
    }

    // Вставляем или обновляем сообщения
    for (final message in messages) {
      batch.insert(
        _tableName,
        {
          'id': message.id,
          'chat_id': message.chatId,
          'sender_id': message.sender.id,
          'sender_username': message.sender.username,
          'sender_email': message.sender.email,
          'sender_avatar': message.sender.avatar,
          'content': message.content,
          'message_type': message.messageType.toString().split('.').last,
          'file_url': message.fileUrl,
          'file_name': message.fileName,
          'is_read': message.isRead ? 1 : 0,
          'created_at': message.createdAt.toIso8601String(),
          'updated_at': message.updatedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Получает сообщения из кэша для указанного чата
  /// Возвращает отсортированные по времени создания (старые первыми)
  Future<List<Message>> getCachedMessages(int chatId, {int? limit, int? offset}) async {
    final db = await database;
    
    String query = '''
      SELECT * FROM $_tableName 
      WHERE chat_id = ? 
      ORDER BY created_at ASC
    ''';
    
    List<dynamic> args = [chatId];
    
    if (limit != null) {
      query += ' LIMIT ?';
      args.add(limit);
      if (offset != null) {
        query += ' OFFSET ?';
        args.add(offset);
      }
    }

    final results = await db.rawQuery(query, args);
    
    return results.map((row) => _messageFromRow(row)).toList();
  }

  /// Получает последние N сообщений из кэша (самые новые)
  Future<List<Message>> getLastCachedMessages(int chatId, int count) async {
    final db = await database;
    
    final results = await db.rawQuery('''
      SELECT * FROM $_tableName 
      WHERE chat_id = ? 
      ORDER BY created_at DESC 
      LIMIT ?
    ''', [chatId, count]);
    
    final messages = results.map((row) => _messageFromRow(row)).toList();
    // Возвращаем в правильном порядке (старые первыми)
    return messages.reversed.toList();
  }

  /// Получает самое старое сообщение из кэша для указанного чата
  Future<Message?> getOldestCachedMessage(int chatId) async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT * FROM $_tableName 
      WHERE chat_id = ? 
      ORDER BY created_at ASC 
      LIMIT 1
    ''', [chatId]);
    
    if (result.isEmpty) return null;
    return _messageFromRow(result.first);
  }

  /// Получает самое новое сообщение из кэша для указанного чата
  Future<Message?> getNewestCachedMessage(int chatId) async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT * FROM $_tableName 
      WHERE chat_id = ? 
      ORDER BY created_at DESC 
      LIMIT 1
    ''', [chatId]);
    
    if (result.isEmpty) return null;
    return _messageFromRow(result.first);
  }

  /// Получает количество закэшированных сообщений для чата
  Future<int> getCachedMessagesCount(int chatId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM $_tableName WHERE chat_id = ?',
      [chatId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Удаляет все сообщения для указанного чата из кэша
  Future<void> clearCacheForChat(int chatId) async {
    final db = await database;
    await db.delete(_tableName, where: 'chat_id = ?', whereArgs: [chatId]);
  }

  /// Удаляет все сообщения из кэша
  Future<void> clearAllCache() async {
    final db = await database;
    await db.delete(_tableName);
  }

  /// Обновляет сообщение в кэше
  Future<void> updateMessage(Message message) async {
    final db = await database;
    await db.update(
      _tableName,
      {
        'sender_id': message.sender.id,
        'sender_username': message.sender.username,
        'sender_email': message.sender.email,
        'sender_avatar': message.sender.avatar,
        'content': message.content,
        'message_type': message.messageType.toString().split('.').last,
        'file_url': message.fileUrl,
        'file_name': message.fileName,
        'is_read': message.isRead ? 1 : 0,
        'updated_at': message.updatedAt.toIso8601String(),
      },
      where: 'id = ? AND chat_id = ?',
      whereArgs: [message.id, message.chatId],
    );
  }

  /// Добавляет новое сообщение в кэш
  Future<void> addMessage(Message message) async {
    final db = await database;
    
    // Проверяем, не превышен ли лимит
    final count = await getCachedMessagesCount(message.chatId);
    if (count >= _maxCachedMessages) {
      // Удаляем самое старое сообщение
      final oldest = await getOldestCachedMessage(message.chatId);
      if (oldest != null) {
        await db.delete(
          _tableName,
          where: 'id = ? AND chat_id = ?',
          whereArgs: [oldest.id, message.chatId],
        );
      }
    }
    
    await db.insert(
      _tableName,
      {
        'id': message.id,
        'chat_id': message.chatId,
        'sender_id': message.sender.id,
        'sender_username': message.sender.username,
        'sender_email': message.sender.email,
        'sender_avatar': message.sender.avatar,
        'content': message.content,
        'message_type': message.messageType.toString().split('.').last,
        'file_url': message.fileUrl,
        'file_name': message.fileName,
        'is_read': message.isRead ? 1 : 0,
        'created_at': message.createdAt.toIso8601String(),
        'updated_at': message.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Message _messageFromRow(Map<String, dynamic> row) {
    final sender = User(
      id: row['sender_id'] as int,
      username: row['sender_username'] as String,
      email: row['sender_email'] as String,
      avatar: row['sender_avatar'] as String?,
      isOnline: null,
      lastSeen: null,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );

    return Message(
      id: row['id'] as int,
      chatId: row['chat_id'] as int,
      sender: sender,
      content: row['content'] as String,
      messageType: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == row['message_type'] as String,
        orElse: () => MessageType.text,
      ),
      fileUrl: row['file_url'] as String?,
      fileName: row['file_name'] as String?,
      isRead: (row['is_read'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}

