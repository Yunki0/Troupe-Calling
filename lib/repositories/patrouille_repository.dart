import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/models.dart';

class PatrouilleRepository {
  final DatabaseHelper _databaseHelper;

  PatrouilleRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<List<Patrouille>> getAll() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('patrouilles', orderBy: 'nom COLLATE NOCASE ASC');
    return rows.map(Patrouille.fromMap).toList();
  }

  Future<Patrouille?> findById(String id) async {
    final db = await _databaseHelper.database;
    final rows =
        await db.query('patrouilles', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Patrouille.fromMap(rows.first);
  }

  /// Lève une [StateError] si une patrouille porte déjà ce nom.
  Future<void> save(Patrouille patrouille) async {
    final db = await _databaseHelper.database;
    try {
      await db.insert('patrouilles', patrouille.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw StateError('Une patrouille porte déjà ce nom.');
      }
      rethrow;
    }
  }

  Future<void> rename(String id, String nom, String? couleur) async {
    final db = await _databaseHelper.database;
    try {
      await db.update('patrouilles', {'nom': nom.trim(), 'couleur': couleur},
          where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw StateError('Une patrouille porte déjà ce nom.');
      }
      rethrow;
    }
  }

  /// Supprime la patrouille. Les jeunes qui en faisaient partie deviennent
  /// "sans patrouille" (ON DELETE SET NULL défini dans le schéma).
  Future<void> delete(String id) async {
    final db = await _databaseHelper.database;
    await db.delete('patrouilles', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countMembers(String patrouilleId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM scouts WHERE patrouille_id = ?',
      [patrouilleId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}