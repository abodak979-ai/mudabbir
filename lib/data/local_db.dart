import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Offline-first local store. Every synced table is kept as JSON rows with a dirty flag;
/// the user's data set is small, so the app loads it fully into memory.
class LocalDb {
  LocalDb._(this._db);
  final Database _db;

  static Future<LocalDb> open() async {
    final path = p.join(await getDatabasesPath(), 'mudabbir.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE rows (tbl TEXT NOT NULL, id TEXT NOT NULL, data TEXT NOT NULL, '
          'dirty INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (tbl, id))',
        );
        await db.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)');
      },
    );
    return LocalDb._(db);
  }

  Future<List<Map<String, dynamic>>> all(String tbl) async {
    final rows = await _db.query('rows', columns: ['data'], where: 'tbl = ?', whereArgs: [tbl]);
    return [for (final r in rows) jsonDecode(r['data'] as String) as Map<String, dynamic>];
  }

  Future<List<Map<String, dynamic>>> dirty(String tbl) async {
    final rows = await _db.query('rows', columns: ['data'], where: 'tbl = ? AND dirty = 1', whereArgs: [tbl]);
    return [for (final r in rows) jsonDecode(r['data'] as String) as Map<String, dynamic>];
  }

  Future<bool> isDirty(String tbl, String id) async {
    final rows = await _db.query('rows', columns: ['dirty'], where: 'tbl = ? AND id = ?', whereArgs: [tbl, id]);
    return rows.isNotEmpty && rows.first['dirty'] == 1;
  }

  Future<void> put(String tbl, Map<String, dynamic> data, {bool dirty = true}) => _db.insert(
        'rows',
        {'tbl': tbl, 'id': data['id'], 'data': jsonEncode(data), 'dirty': dirty ? 1 : 0},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<String?> meta(String key) async {
    final r = await _db.query('meta', where: 'key = ?', whereArgs: [key]);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) =>
      _db.insert('meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<int> pendingCount() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM rows WHERE dirty = 1')) ?? 0;

  Future<void> clear() async {
    await _db.delete('rows');
    await _db.delete('meta');
  }
}
