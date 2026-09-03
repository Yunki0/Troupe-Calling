import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/models.dart';

class ScoutRepository {
  final DatabaseHelper _databaseHelper;

  ScoutRepository({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<List<Scout>> getAll({bool includeInactive = true}) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'scouts',
      where: includeInactive ? null : 'statut = ?',
      whereArgs: includeInactive ? null : ['actif'],
      orderBy: 'nom COLLATE NOCASE ASC, prenom COLLATE NOCASE ASC',
    );
    return rows.map(Scout.fromMap).toList();
  }

  Future<List<Scout>> getForPatrouille(String patrouilleId) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'scouts',
      where: 'patrouille_id = ?',
      whereArgs: [patrouilleId],
      orderBy:
          "CASE role_patrouille WHEN 'chef' THEN 0 WHEN 'second' THEN 1 ELSE 2 END, "
          'nom COLLATE NOCASE ASC',
    );
    return rows.map(Scout.fromMap).toList();
  }

  Future<List<Scout>> getSansPatrouille() async {
    final db = await _databaseHelper.database;
    final rows = await db.query('scouts',
        where: 'patrouille_id IS NULL', orderBy: 'nom COLLATE NOCASE ASC');
    return rows.map(Scout.fromMap).toList();
  }

  Future<Scout?> findByQrToken(String qrToken) async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'scouts',
      where: 'qr_token = ?',
      whereArgs: [qrToken],
      limit: 1,
    );
    return rows.isEmpty ? null : Scout.fromMap(rows.first);
  }

  Future<Scout?> findById(String id) async {
    final db = await _databaseHelper.database;
    final rows =
        await db.query('scouts', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Scout.fromMap(rows.first);
  }

  Future<void> save(Scout scout) async {
    final db = await _databaseHelper.database;
    await db.insert(
      'scouts',
      scout.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateStatus(String id, ScoutStatus status) async {
    final db = await _databaseHelper.database;
    await db.update(
      'scouts',
      {'statut': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateProfile({
    required String id,
    required String prenom,
    required String nom,
  }) async {
    final db = await _databaseHelper.database;
    await db.update(
      'scouts',
      {'prenom': prenom.trim(), 'nom': nom.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Met à jour la fiche technique complète du jeune.
  Future<void> updateFicheTechnique({
    required String id,
    String? dateNaissance,
    String? lieuNaissance,
    String? adresse,
    String? parentNom,
    String? parentContact,
  }) async {
    final db = await _databaseHelper.database;
    await db.update(
      'scouts',
      {
        'date_naissance': dateNaissance,
        'lieu_naissance': lieuNaissance,
        'adresse': adresse,
        'parent_nom': parentNom,
        'parent_contact': parentContact,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updatePhoto(String id, String? photoPath) async {
    final db = await _databaseHelper.database;
    await db.update(
      'scouts',
      {'photo_path': photoPath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Affecte (ou retire, si [patrouilleId] est null) un jeune à une
  /// patrouille avec un rôle donné. Lève une [StateError] si le rôle
  /// chef/second est déjà occupé dans cette patrouille par quelqu'un d'autre.
  Future<void> assignPatrouille({
    required String scoutId,
    required String? patrouilleId,
    RolePatrouille role = RolePatrouille.membre,
  }) async {
    final db = await _databaseHelper.database;
    try {
      await db.update(
        'scouts',
        {
          'patrouille_id': patrouilleId,
          'role_patrouille': patrouilleId == null ? 'membre' : role.name,
        },
        where: 'id = ?',
        whereArgs: [scoutId],
      );
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        final label = role == RolePatrouille.chef ? 'chef de patrouille' : 'second';
        throw StateError('Cette patrouille a déjà un $label.');
      }
      rethrow;
    }
  }
}
