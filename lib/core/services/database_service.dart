import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/chat/models/message_model.dart';
import '../../features/chat/models/pending_message_model.dart';

int? _firstIntValue(List<Map<String, Object?>>? results) {
  if (results == null || results.isEmpty) return null;
  return results.first.values.firstOrNull as int?;
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (Platform.isWindows || Platform.isLinux) {
      ffi.sqfliteFfiInit();
      _database = await _initDbFfi();
    } else {
      _database = await _initDb();
    }
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'local_social.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<Database> _initDbFfi() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbDir = join(docsDir.path, 'databases');
    await Directory(dbDir).create(recursive: true);
    final path = join(dbDir, 'local_social.db');
    return await ffi.databaseFactoryFfi.openDatabase(
      path,
      options: ffi.OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) => _onCreate(db, version),
        onUpgrade: (db, oldVersion, newVersion) => _onUpgrade(db, oldVersion, newVersion),
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        senderId TEXT NOT NULL,
        receiverId TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        isRead INTEGER NOT NULL DEFAULT 0,
        edited INTEGER NOT NULL DEFAULT 0,
        editedAt TEXT
      )
    ''');

    await _createPendingMessagesTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createPendingMessagesTable(db);
    }
  }

  Future<void> _createPendingMessagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_messages (
        id TEXT PRIMARY KEY,
        senderId TEXT NOT NULL,
        receiverId TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        messageType TEXT NOT NULL DEFAULT 'text',
        groupId TEXT,
        fileMetadata TEXT,
        retryCount INTEGER NOT NULL DEFAULT 0,
        lastAttemptAt TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pending_receiver
      ON pending_messages(receiverId, status)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pending_group
      ON pending_messages(groupId)
    ''');
  }

  // --- User Methods ---
  Future<void> insertUser(User user) async {
    final db = await database;
    await db.insert('users', user.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<User?> getUser(String id) async {
    final db = await database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return User.fromJson(maps.first);
    }
    return null;
  }

  // --- Message Methods ---
  Future<void> insertMessage(Message message) async {
    final db = await database;
    final json = message.toJson();
    json['isRead'] = json.remove('read') == true ? 1 : 0;
    if (json['edited'] is bool) json['edited'] = json['edited'] ? 1 : 0;
    await db.insert('messages', json, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Message>> getMessagesForUser(String userId, String friendId) async {
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT id, senderId, receiverId, content, timestamp, isRead as "read", edited, editedAt FROM messages WHERE (senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?) ORDER BY timestamp ASC',
      [userId, friendId, friendId, userId],
    );
    return maps.map((json) => Message.fromJson(json)).toList();
  }
  
  Future<void> deleteMessage(String messageId) async {
    final db = await database;
    await db.delete('messages', where: 'id = ?', whereArgs: [messageId]);
  }

  Future<void> updateMessageContent(String messageId, String newContent) async {
    final db = await database;
    await db.update(
      'messages',
      {
        'content': newContent,
        'edited': 1,
        'editedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // --- Pending Message Methods ---

  Future<void> insertPendingMessage(PendingMessage pending) async {
    final db = await database;
    await db.insert('pending_messages', pending.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<PendingMessage?> getPendingMessage(String id) async {
    final db = await database;
    final maps = await db.query('pending_messages', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return PendingMessage.fromJson(maps.first);
    return null;
  }

  Future<List<PendingMessage>> getPendingMessagesForReceiver(String receiverId) async {
    final db = await database;
    final maps = await db.query(
      'pending_messages',
      where: 'receiverId = ? AND status = ?',
      whereArgs: [receiverId, 'pending'],
      orderBy: 'timestamp ASC',
    );
    return maps.map((json) => PendingMessage.fromJson(json)).toList();
  }

  Future<List<PendingMessage>> getAllPendingMessages() async {
    final db = await database;
    final maps = await db.query('pending_messages', orderBy: 'timestamp ASC');
    return maps.map((json) => PendingMessage.fromJson(json)).toList();
  }

  Future<void> updatePendingStatus(String id, DeliveryStatus status) async {
    final db = await database;
    await db.update('pending_messages', {'status': status.name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePendingRetry(String id, int retryCount, DateTime lastAttempt) async {
    final db = await database;
    await db.update('pending_messages', {
      'retryCount': retryCount,
      'lastAttemptAt': lastAttempt.toUtc().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePendingContent(String id, String newContent) async {
    final db = await database;
    await db.update('pending_messages', {'content': newContent}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePendingMessage(String id) async {
    final db = await database;
    await db.delete('pending_messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePendingMessagesForReceiver(String receiverId) async {
    final db = await database;
    await db.delete('pending_messages', where: 'receiverId = ?', whereArgs: [receiverId]);
  }

  Future<void> deletePendingMessagesForGroup(String groupId) async {
    final db = await database;
    await db.delete('pending_messages', where: 'groupId = ?', whereArgs: [groupId]);
  }

  Future<int> getPendingMessageCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM pending_messages WHERE status = ?', ['pending']);
    return _firstIntValue(result) ?? 0;
  }

  Future<int> getPendingMessageCountForReceiver(String receiverId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pending_messages WHERE receiverId = ? AND status = ?',
      [receiverId, 'pending'],
    );
    return _firstIntValue(result) ?? 0;
  }

  Future<List<Message>> getAllMessages() async {
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT id, senderId, receiverId, content, timestamp, isRead as "read", edited, editedAt FROM messages ORDER BY timestamp ASC',
    );
    return maps.map((json) => Message.fromJson(json)).toList();
  }

  Future<void> deleteSentPendingMessages() async {
    final db = await database;
    await db.delete('pending_messages', where: 'status = ?', whereArgs: ['sent']);
  }

  Future<void> resetStuckPendingMessages() async {
    final db = await database;
    await db.update(
      'pending_messages',
      {'status': 'pending'},
      where: 'status = ?',
      whereArgs: ['sending'],
    );
  }
}
