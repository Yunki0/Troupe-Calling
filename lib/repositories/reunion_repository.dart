import '../db/database_helper.dart';
import '../models/models.dart';
import 'package:sqflite/sqflite.dart';

class ReunionRepository {
  final DatabaseHelper _databaseHelper;

  ReunionRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<Reunion?> getOpen() async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'reunions',
      where: 'statut = ?',
      whereArgs: [ReunionStatus.ouverte.name],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : Reunion.fromMap(rows.first);
  }

  Future<List<Reunion>> getAll() async {
    final db = await _databaseHelper.database;
    final rows =
        await db.query('reunions', orderBy: 'date DESC, created_at DESC');
    return rows.map(Reunion.fromMap).toList();
  }

  Future<void> create(Reunion reunion) async {
    final db = await _databaseHelper.database;
    final openReunion = await getOpen();
    if (openReunion != null) {
      throw StateError('Une réunion est déjà ouverte.');
    }
    try {
      await db.insert('reunions', reunion.toMap());
    } on DatabaseException catch (error) {
      if (error.toString().contains('idx_one_open_reunion')) {
        throw StateError('Une réunion est déjà ouverte.');
      }
      rethrow;
    }
  }

  /// Termine la réunion ouverte identifiée par [id].
  ///
  /// Lève une [StateError] si aucune ligne n'a été modifiée — ce qui
  /// signifie soit que la réunion n'existe pas, soit qu'elle est déjà
  /// terminée. Sans cette vérification, l'écran affichait "Réunion
  /// terminée" même quand rien ne s'était réellement passé en base.
  Future<void> finish(String id, {required String heureFin}) async {
    final db = await _databaseHelper.database;
    final count = await db.update(
      'reunions',
      {
        'heure_fin': heureFin,
        'statut': ReunionStatus.terminee.name,
      },
      where: 'id = ? AND statut = ?',
      whereArgs: [id, ReunionStatus.ouverte.name],
    );
    if (count == 0) {
      throw StateError('Cette réunion est déjà terminée ou introuvable.');
    }
  }

  /// Met à jour le compte-rendu d'une réunion encore ouverte.
  ///
  /// Même principe que [finish] : une mise à jour silencieuse de 0 ligne
  /// (réunion déjà terminée, ou id inconnu) devient une erreur explicite
  /// plutôt qu'un faux succès.
  Future<void> updateNotes(String id, String compteRendu) async {
    final db = await _databaseHelper.database;
    final count = await db.update(
      'reunions',
      {'compte_rendu': compteRendu.trim()},
      where: 'id = ? AND statut = ?',
      whereArgs: [id, ReunionStatus.ouverte.name],
    );
    if (count == 0) {
      throw StateError('Impossible de modifier : réunion déjà terminée ou introuvable.');
    }
  }
}
