import '../core/database/database_helper.dart';

class ContactService {
  ContactService._();
  static final ContactService instance = ContactService._();

  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<String?> getNickname(String contactId) async {
    final result = await _db.query(
      'contact_nicknames',
      where: 'contact_id = ?',
      whereArgs: [contactId],
    );
    if (result.isNotEmpty) {
      return result.first['nickname'] as String?;
    }
    return null;
  }

  Future<void> setNickname(String contactId, String nickname) async {
    final now = DateTime.now().toIso8601String();
    final existing = await _db.query(
      'contact_nicknames',
      where: 'contact_id = ?',
      whereArgs: [contactId],
    );
    if (existing.isNotEmpty) {
      await _db.update(
        'contact_nicknames',
        {'nickname': nickname, 'updated_at': now},
        'contact_id = ?',
        [contactId],
      );
    } else {
      await _db.insert('contact_nicknames', {
        'contact_id': contactId,
        'nickname': nickname,
        'updated_at': now,
      });
    }
  }

  Future<void> removeNickname(String contactId) async {
    await _db.delete('contact_nicknames', 'contact_id = ?', [contactId]);
  }

  Future<Map<String, String>> getAllNicknames() async {
    final result = await _db.query('contact_nicknames');
    final map = <String, String>{};
    for (final row in result) {
      map[row['contact_id'] as String] = row['nickname'] as String;
    }
    return map;
  }
}
