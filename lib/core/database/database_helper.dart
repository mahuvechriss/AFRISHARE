import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../constants/app_constants.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    try {
      await db.rawQuery('PRAGMA journal_mode = WAL;');
    } catch (_) {}
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        profile_picture TEXT,
        device_id TEXT NOT NULL,
        device_name TEXT NOT NULL,
        is_guest INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Devices table
    await db.execute('''
      CREATE TABLE devices (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        device_id TEXT UNIQUE NOT NULL,
        device_type TEXT NOT NULL,
        status TEXT DEFAULT 'offline',
        last_seen TEXT,
        is_paired INTEGER DEFAULT 0,
        is_blocked INTEGER DEFAULT 0,
        is_hidden INTEGER DEFAULT 0,
        public_key TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Transfers table
    await db.execute('''
      CREATE TABLE transfers (
        id TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        file_path TEXT,
        file_size INTEGER NOT NULL,
        file_type TEXT NOT NULL,
        mime_type TEXT,
        sender_id TEXT NOT NULL,
        sender_name TEXT,
        receiver_id TEXT NOT NULL,
        receiver_name TEXT,
        direction TEXT NOT NULL,
        status TEXT NOT NULL,
        progress REAL DEFAULT 0,
        speed REAL DEFAULT 0,
        encryption_key TEXT,
        encryption_iv TEXT,
        is_encrypted INTEGER DEFAULT 1,
        error_message TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        completed_at TEXT
      )
    ''');

    // Chat messages table
    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        sender_name TEXT,
        receiver_id TEXT NOT NULL,
        receiver_name TEXT,
        message TEXT,
        message_type TEXT DEFAULT 'text',
        file_path TEXT,
        file_name TEXT,
        file_size INTEGER,
        is_encrypted INTEGER DEFAULT 1,
        is_read INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Shared resources table (Community Library)
    await db.execute('''
      CREATE TABLE shared_resources (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        sub_category TEXT,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        file_type TEXT NOT NULL,
        thumbnail_path TEXT,
        uploader_id TEXT NOT NULL,
        uploader_name TEXT,
        download_count INTEGER DEFAULT 0,
        rating REAL DEFAULT 0,
        tags TEXT,
        is_featured INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (uploader_id) REFERENCES users(id)
      )
    ''');

    // Notifications table
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        data TEXT,
        is_read INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Settings table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Paired device keys table
    await db.execute('''
      CREATE TABLE paired_keys (
        device_id TEXT PRIMARY KEY,
        device_name TEXT NOT NULL,
        encryption_key TEXT NOT NULL,
        encryption_iv TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Contact nicknames table
    await db.execute('''
      CREATE TABLE contact_nicknames (
        contact_id TEXT PRIMARY KEY,
        nickname TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Pending messages table (offline message delivery)
    await db.execute('''
      CREATE TABLE pending_messages (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        receiver_id TEXT NOT NULL,
        receiver_name TEXT NOT NULL,
        message TEXT,
        message_type TEXT DEFAULT 'text',
        created_at TEXT NOT NULL
      )
    ''');

    // Insert default settings
    await _insertDefaultSettings(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration: v1 -> v2 — add paired_keys table
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS paired_keys (
          device_id TEXT PRIMARY KEY,
          device_name TEXT NOT NULL,
          encryption_key TEXT NOT NULL,
          encryption_iv TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }
    // Migration: v2 -> v3 — add contact_nicknames table
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS contact_nicknames (
          contact_id TEXT PRIMARY KEY,
          nickname TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }
    // Migration: v3 -> v4 — add pending_messages table for offline delivery
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_messages (
          id TEXT PRIMARY KEY,
          sender_id TEXT NOT NULL,
          sender_name TEXT NOT NULL,
          receiver_id TEXT NOT NULL,
          receiver_name TEXT NOT NULL,
          message TEXT,
          message_type TEXT DEFAULT 'text',
          created_at TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _insertDefaultSettings(Database db) async {
    final now = DateTime.now().toIso8601String();
    final defaultSettings = [
      {'key': 'theme_mode', 'value': 'system', 'updated_at': now},
      {'key': 'auto_accept_transfers', 'value': 'false', 'updated_at': now},
      {'key': 'auto_discovery', 'value': 'true', 'updated_at': now},
      {'key': 'encryption_enabled', 'value': 'true', 'updated_at': now},
      {'key': 'max_simultaneous_transfers', 'value': '3', 'updated_at': now},
      {'key': 'storage_limit_mb', 'value': '1024', 'updated_at': now},
      {'key': 'auto_cleanup', 'value': 'true', 'updated_at': now},
      {'key': 'device_name', 'value': '', 'updated_at': now},
      {'key': 'device_hidden', 'value': 'false', 'updated_at': now},
      {'key': 'notifications_enabled', 'value': 'true', 'updated_at': now},
      {'key': 'data_saver_mode', 'value': 'false', 'updated_at': now},
      {'key': 'language', 'value': 'en', 'updated_at': now},
    ];

    for (final setting in defaultSettings) {
      await db.insert('settings', setting);
    }
  }

  // Generic CRUD Operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<int> update(String table, Map<String, dynamic> data, String where,
      List<dynamic> whereArgs) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, String where, List<dynamic> whereArgs) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> query(String table,
      {String? where,
      List<dynamic>? whereArgs,
      String? orderBy,
      int? limit,
      int? offset}) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  // Settings operations
  Future<String?> getSetting(String key) async {
    final result = await query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isNotEmpty) {
      return result.first['value'] as String?;
    }
    return null;
  }

  Future<void> setSetting(String key, String value) async {
    final now = DateTime.now().toIso8601String();
    final existing = await getSetting(key);
    if (existing != null) {
      await update(
        'settings',
        {'value': value, 'updated_at': now},
        'key = ?',
        [key],
      );
    } else {
      await insert('settings', {
        'key': key,
        'value': value,
        'updated_at': now,
      });
    }
  }

  // Statistics queries
  Future<int> getTotalTransfers() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM transfers');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalFilesShared() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM transfers WHERE direction = "sent"');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalStorageUsed() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COALESCE(SUM(file_size), 0) as total FROM transfers WHERE status = "completed"');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, int>> getTransfersByStatus() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT status, COUNT(*) as count 
      FROM transfers 
      GROUP BY status
    ''');
    final map = <String, int>{};
    for (final row in result) {
      map[row['status'] as String] = row['count'] as int;
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> getMostSharedContent(
      {int limit = 10}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT file_type, COUNT(*) as count, SUM(file_size) as total_size
      FROM transfers 
      WHERE direction = 'sent'
      GROUP BY file_type
      ORDER BY count DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<int> getActiveDevices() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM devices WHERE status = "online"');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Clear all data (for reset)
  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transfers');
      await txn.delete('chat_messages');
      await txn.delete('shared_resources');
      await txn.delete('notifications');
      await txn.delete('devices');
      await txn.delete('paired_keys');
    });
  }

  // Paired keys operations
  Future<void> savePairedKeys(String deviceId, String deviceName, String key, String iv) async {
    final now = DateTime.now().toIso8601String();
    final db = await database;
    await db.insert(
      'paired_keys',
      {
        'device_id': deviceId,
        'device_name': deviceName,
        'encryption_key': key,
        'encryption_iv': iv,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getPairedKeys(String deviceId) async {
    final result = await query(
      'paired_keys',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllPairedKeys() async {
    return await query('paired_keys');
  }

  Future<void> deletePairedKeys(String deviceId) async {
    await delete('paired_keys', 'device_id = ?', [deviceId]);
  }
}
