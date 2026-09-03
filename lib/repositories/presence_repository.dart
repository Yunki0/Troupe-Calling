import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/models.dart';

class PresenceRepository {
  final DatabaseHelper _databaseHelper;

  PresenceRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<bool> add(Presence presence) async {
    final db = await _databaseHelper.database;
    final insertedId = await db.insert(
      'presences',
      presence.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return insertedId != 0;
  }

  Future<bool> exists(
      {required String reunionId, required String scoutId}) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'presences',
      columns: ['id'],
      where: 'reunion_id = ? AND scout_id = ?',
      whereArgs: [reunionId, scoutId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<Presence>> getForReunion(String reunionId) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'presences',
      where: 'reunion_id = ?',
      whereArgs: [reunionId],
      orderBy: 'scanned_at ASC',
    );
    return rows.map(Presence.fromMap).toList();
  }

  Future<void> remove(
      {required String reunionId, required String scoutId}) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'presences',
      where: 'reunion_id = ? AND scout_id = ?',
      whereArgs: [reunionId, scoutId],
    );
  }

  Future<int> countForReunion(String reunionId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM presences WHERE reunion_id = ?',
      [reunionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
