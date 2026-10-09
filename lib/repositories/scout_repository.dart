import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/models.dart';

const int kMaxScoutsPerPatrouille = 7;

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
    final rows = await db.query(
      'scouts',
      where: 'patrouille_id IS NULL',
      orderBy: 'nom COLLATE NOCASE ASC',
    );
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
    final rows = await db.query(
      'scouts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Scout.fromMap(rows.first);
  }

  /// Crée un nouveau scout. Échoue (DatabaseException) si l'id ou le
  /// qr_token existent déjà, plutôt que d'écraser silencieusement une
  /// ligne existante.
  Future<void> create(Scout scout) async {
    final db = await _databaseHelper.database;
    await db.insert('scouts', scout.toMap());
  }

  /// Modifie un scout existant. N'écrase jamais un autre enregistrement :
  /// cible explicitement la ligne par son id.
  Future<void> update(Scout scout) async {
    final db = await _databaseHelper.database;

    final count = await db.update(
      'scouts',
      scout.toMap(),
      where: 'id = ?',
      whereArgs: [scout.id],
    );

    if (count == 0) {
      throw StateError(
        'Impossible de modifier le scout : '
        '${scout.id} introuvable.',
      );
    }
  }

  /// @deprecated — conservé temporairement pour compatibilité, mais ne plus
  /// appeler pour une mise à jour : utilise [update]. Utilise [create] pour
  /// une insertion. Cette méthode disparaîtra une fois tous les appels migrés.
  @Deprecated('Utilise create() ou update() selon le cas.')
  Future<void> save(Scout scout) async {
    final existing = await findById(scout.id);
    if (existing == null) {
      await create(scout);
    } else {
      await update(scout);
    }
  }

  Future<void> updateStatus(String id, ScoutStatus status) async {
    final db = await _databaseHelper.database;
    final count = await db.update(
      'scouts',
      {'statut': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) {
      throw StateError('Scout introuvable (id: $id).');
    }
  }

  Future<void> updateProfile({
    required String id,
    required String prenom,
    required String nom,
  }) async {
    final db = await _databaseHelper.database;
    final count = await db.update(
      'scouts',
      {'prenom': prenom.trim(), 'nom': nom.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) {
      throw StateError('Scout introuvable (id: $id).');
    }
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
    final count = await db.update(
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
    if (count == 0) {
      throw StateError('Scout introuvable (id: $id).');
    }
  }

  Future<void> updatePhoto(String id, String? photoPath) async {
    final db = await _databaseHelper.database;
    final count = await db.update(
      'scouts',
      {'photo_path': photoPath},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) {
      throw StateError('Scout introuvable (id: $id).');
    }
  }

  Future<int> countMembers(String patrouilleId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM scouts WHERE patrouille_id = ?',
      [patrouilleId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Affecte (ou retire, si [patrouilleId] est null) un jeune à une
  /// patrouille avec un rôle donné.
  ///
  /// Lève une [StateError] si :
  /// - le rôle chef/second est déjà occupé dans cette patrouille par
  ///   quelqu'un d'autre (protégé aussi par un index unique en base) ;
  /// - la patrouille a déjà atteint [kMaxScoutsPerPatrouille] membres et que
  ///   ce scout n'en fait pas déjà partie.
  ///
  /// Le contrôle de la limite de [kMaxScoutsPerPatrouille] et l'écriture
  /// sont faits dans une même transaction : avant ce correctif, un
  /// double-tap (ou deux affectations quasi simultanées vers la même
  /// patrouille) pouvait lire le même compte "avant" pour les deux appels et
  /// faire dépasser la limite, car rien ne protégeait cette vérification
  /// entre sa lecture et l'écriture qui suit (contrairement au rôle
  /// chef/second, protégé par un index unique en base).
  Future<void> assignPatrouille({
    required String scoutId,
    required String? patrouilleId,
    RolePatrouille role = RolePatrouille.membre,
  }) async {
    final db = await _databaseHelper.database;

    try {
      await db.transaction((txn) async {
        if (patrouilleId != null) {
          final currentRows = await txn.query(
            'scouts',
            columns: ['patrouille_id'],
            where: 'id = ?',
            whereArgs: [scoutId],
            limit: 1,
          );
          final alreadyInThisPatrouille =
              currentRows.isNotEmpty &&
              currentRows.first['patrouille_id'] == patrouilleId;
          if (!alreadyInThisPatrouille) {
            final countResult = await txn.rawQuery(
              'SELECT COUNT(*) AS count FROM scouts WHERE patrouille_id = ?',
              [patrouilleId],
            );
            final currentCount = Sqflite.firstIntValue(countResult) ?? 0;
            if (currentCount >= kMaxScoutsPerPatrouille) {
              throw StateError(
                'Cette patrouille a déjà atteint sa limite de $kMaxScoutsPerPatrouille membres.',
              );
            }
          }
        }

        final count = await txn.update(
          'scouts',
          {
            'patrouille_id': patrouilleId,
            'role_patrouille': patrouilleId == null ? 'membre' : role.name,
          },
          where: 'id = ?',
          whereArgs: [scoutId],
        );
        if (count == 0) {
          throw StateError('Scout introuvable (id: $scoutId).');
        }
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        final label = role == RolePatrouille.chef
            ? 'chef de patrouille'
            : 'second';
        throw StateError('Cette patrouille a déjà un $label.');
      }
      rethrow;
    }
  }
}
