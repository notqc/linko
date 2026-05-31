import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('linko.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        peerId TEXT NOT NULL,
        peerName TEXT NOT NULL,
        senderId TEXT NOT NULL,
        senderName TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        isMe INTEGER NOT NULL,
        isRelayed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE peers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL,
        lastSeen INTEGER NOT NULL
      )
    ''');

    await db.index('CREATE INDEX idx_messages_peer ON messages(peerId)');
  }

  // ── Messages ────────────────────────────────────────────────

  Future<void> insertMessage(Message msg, String peerId, String peerName) async {
    final db = await database;
    await db.insert('messages', {
      'id': msg.id,
      'peerId': peerId,
      'peerName': peerName,
      'senderId': msg.senderId,
      'senderName': msg.senderName,
      'content': msg.content,
      'timestamp': msg.timestamp.millisecondsSinceEpoch,
      'isMe': msg.isMe ? 1 : 0,
      'isRelayed': msg.isRelayed ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Message>> getMessages(String peerId) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'peerId = ?',
      whereArgs: [peerId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => Message(
      id: m['id'] as String,
      senderId: m['senderId'] as String,
      senderName: m['senderName'] as String,
      content: m['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(m['timestamp'] as int),
      isMe: (m['isMe'] as int) == 1,
      isRelayed: (m['isRelayed'] as int) == 1,
    )).toList();
  }

  Future<void> deleteMessagesForPeer(String peerId) async {
    final db = await database;
    await db.delete('messages', where: 'peerId = ?', whereArgs: [peerId]);
  }

  Future<void> deleteAllMessages() async {
    final db = await database;
    await db.delete('messages');
  }

  // ── Peers ───────────────────────────────────────────────────

  Future<void> upsertPeer(Peer peer) async {
    final db = await database;
    await db.insert('peers', {
      'id': peer.id,
      'name': peer.name,
      'emoji': peer.emoji,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Peer>> getKnownPeers() async {
    final db = await database;
    final maps = await db.query('peers', orderBy: 'lastSeen DESC');
    return maps.map((m) => Peer(
      id: m['id'] as String,
      name: m['name'] as String,
      emoji: m['emoji'] as String,
    )).toList();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

extension on Database {
  Future<void> index(String sql) async => await execute(sql);
}
