import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

class DatabaseHelper {
  final DatabaseFactory _databaseFactory;
  final String? _databasePath;

  DatabaseHelper._internal({
    DatabaseFactory? factory,
    String? databasePath,
  })  : _databaseFactory = factory ?? databaseFactory,
        _databasePath = databasePath;

  static final DatabaseHelper instance = DatabaseHelper._internal();

  DatabaseHelper.forTesting({
    required DatabaseFactory databaseFactory,
    required String databasePath,
  }) : this._internal(factory: databaseFactory, databasePath: databasePath);

  Future<void> close() async {
    final db = _db;
    _db = null;
    _dbFuture = null;
    await db?.close();
  }

  Database? _db;
  Future<Database>? _dbFuture;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db ??= await (_dbFuture ??= _initDb());
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = _databasePath ?? await _databaseFactory.getDatabasesPath();
    final path = _databasePath ?? join(dbPath, 'appel_scout.db');
    return _databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE roster (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            createdAt INTEGER NOT NULL
          )
        ''');
          await db.execute('''
          CREATE TABLE attendance (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            youthId TEXT NOT NULL,
            time TEXT NOT NULL
          )
        ''');
          await db
              .execute('CREATE INDEX idx_attendance_date ON attendance(date)');
          await db.execute(
            'CREATE UNIQUE INDEX idx_attendance_date_youth '
            'ON attendance(date, youthId)',
          );
          await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
          await _createTargetTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'CREATE UNIQUE INDEX IF NOT EXISTS '
              'idx_attendance_date_youth ON attendance(date, youthId)',
            );
          }
          if (oldVersion < 3) {
            await _createTargetTables(db);
            await db.execute('''
            INSERT OR IGNORE INTO scouts
              (id, nom, prenom, qr_token, statut, created_at)
            SELECT id, '', name, id, 'actif', createdAt FROM roster
          ''');
            await db.execute('''
            INSERT OR IGNORE INTO reunions
              (id, date, heure_debut, heure_fin, compte_rendu,
               created_by, total_scouts, statut, created_at)
            SELECT 'legacy-' || date, date, '00:00', NULL, NULL,
                   'legacy',
                   (SELECT COUNT(*) FROM scouts WHERE statut = 'actif'),
                   'terminee', strftime('%s', date) * 1000
            FROM (SELECT DISTINCT date FROM attendance)
          ''');
            await db.execute('''
            INSERT OR IGNORE INTO presences
              (id, reunion_id, scout_id, scanned_at)
            SELECT a.id, 'legacy-' || a.date, a.youthId, a.time
            FROM attendance a
            INNER JOIN scouts s ON s.id = a.youthId
          ''');
          }
          if (oldVersion < 4) {
            await db.execute('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_one_open_reunion
            ON reunions(statut) WHERE statut = 'ouverte'
          ''');
          }
          if (oldVersion < 5) {
            await _createPatrouilleTables(db);
            await _addScoutV2Columns(db);
          }
        },
      ),
    );
  }

  Future<void> _createTargetTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS scouts (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL DEFAULT '',
        prenom TEXT NOT NULL,
        qr_token TEXT NOT NULL UNIQUE,
        statut TEXT NOT NULL DEFAULT 'actif'
          CHECK (statut IN ('actif', 'inactif')),
        created_at INTEGER NOT NULL,
        date_naissance TEXT,
        lieu_naissance TEXT,
        adresse TEXT,
        parent_nom TEXT,
        parent_contact TEXT,
        photo_path TEXT,
        patrouille_id TEXT REFERENCES patrouilles(id) ON DELETE SET NULL,
        role_patrouille TEXT NOT NULL DEFAULT 'membre'
          CHECK (role_patrouille IN ('membre', 'second', 'chef'))
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reunions (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        heure_debut TEXT NOT NULL,
        heure_fin TEXT,
        compte_rendu TEXT,
        created_by TEXT,
        total_scouts INTEGER NOT NULL DEFAULT 0,
        statut TEXT NOT NULL DEFAULT 'ouverte'
          CHECK (statut IN ('ouverte', 'terminee')),
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_one_open_reunion
      ON reunions(statut) WHERE statut = 'ouverte'
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS presences (
        id TEXT PRIMARY KEY,
        reunion_id TEXT NOT NULL,
        scout_id TEXT NOT NULL,
        scanned_at TEXT NOT NULL,
        FOREIGN KEY (reunion_id) REFERENCES reunions(id) ON DELETE CASCADE,
        FOREIGN KEY (scout_id) REFERENCES scouts(id)
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_presences_reunion_scout
      ON presences(reunion_id, scout_id)
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_presences_reunion ON presences(reunion_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_presences_scout ON presences(scout_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reunions_date ON reunions(date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_scouts_qr_token ON scouts(qr_token)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_scouts_statut ON scouts(statut)');
    await _createPatrouilleTables(db);
  }

  /// Table des patrouilles + index associés. Idempotent (IF NOT EXISTS partout)
  /// pour pouvoir être appelée aussi bien à la création qu'à la migration.
  Future<void> _createPatrouilleTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS patrouilles (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL UNIQUE,
        couleur TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_scouts_patrouille ON scouts(patrouille_id)');
  }

  /// Ajoute les colonnes v2 (fiche technique, photo, patrouille) à une table
  /// `scouts` existante. SQLite n'autorise qu'une colonne par ALTER TABLE,
  /// donc on vérifie d'abord ce qui existe déjà pour rester idempotent.
  Future<void> _addScoutV2Columns(DatabaseExecutor db) async {
    final info = await db.rawQuery('PRAGMA table_info(scouts)');
    final existing = info.map((row) => row['name'] as String).toSet();

    final columns = <String, String>{
      'date_naissance': 'TEXT',
      'lieu_naissance': 'TEXT',
      'adresse': 'TEXT',
      'parent_nom': 'TEXT',
      'parent_contact': 'TEXT',
      'photo_path': 'TEXT',
      'patrouille_id': 'TEXT REFERENCES patrouilles(id) ON DELETE SET NULL',
      'role_patrouille':
          "TEXT NOT NULL DEFAULT 'membre' CHECK (role_patrouille IN ('membre','second','chef'))",
    };

    for (final entry in columns.entries) {
      if (!existing.contains(entry.key)) {
        await db.execute(
            'ALTER TABLE scouts ADD COLUMN ${entry.key} ${entry.value}');
      }
    }

    // Un seul CP et un seul SP actif par patrouille (index partiels).
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_one_cp_per_patrouille
      ON scouts(patrouille_id, role_patrouille)
      WHERE role_patrouille = 'chef' AND patrouille_id IS NOT NULL
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_one_sp_per_patrouille
      ON scouts(patrouille_id, role_patrouille)
      WHERE role_patrouille = 'second' AND patrouille_id IS NOT NULL
    ''');
  }

  // ---- Roster (legacy v1, conservé pour compatibilité) ----
  Future<List<Youth>> getRoster() async {
    final db = await database;
    final rows = await db.query('roster', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map((r) => Youth.fromMap(r)).toList();
  }

  Future<void> addYouth(Youth youth) async {
    final db = await database;
    await db.insert('roster', youth.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteYouth(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('attendance', where: 'youthId = ?', whereArgs: [id]);
      await txn.delete('roster', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---- Attendance (legacy v1) ----
  Future<List<AttendanceRecord>> getAttendanceForDate(String date) async {
    final db = await database;
    final rows =
        await db.query('attendance', where: 'date = ?', whereArgs: [date]);
    return rows.map((r) => AttendanceRecord.fromMap(r)).toList();
  }

  Future<void> markAttendance(String date, String youthId, String time) async {
    final db = await database;
    final rec = AttendanceRecord(
        id: '$date::$youthId', date: date, youthId: youthId, time: time);
    await db.insert('attendance', rec.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> unmarkAttendance(String date, String youthId) async {
    final db = await database;
    await db
        .delete('attendance', where: 'id = ?', whereArgs: ['$date::$youthId']);
  }

  // ---- Settings ----
  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
