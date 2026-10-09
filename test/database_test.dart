import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:troupe_manager/db/database_helper.dart';
import 'package:troupe_manager/models/models.dart';
import 'package:troupe_manager/repositories/presence_repository.dart';
import 'package:troupe_manager/repositories/reunion_repository.dart';
import 'package:troupe_manager/repositories/scout_repository.dart';

void main() {
  late Directory temporaryDirectory;
  late DatabaseHelper databaseHelper;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('troupe_manager_test_');
    databaseHelper = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: '${temporaryDirectory.path}/test.db',
    );
  });

  tearDown(() async {
    await databaseHelper.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('prevents duplicate presence for one scout in one reunion', () async {
    final scoutRepository = ScoutRepository(databaseHelper: databaseHelper);
    final reunionRepository = ReunionRepository(databaseHelper: databaseHelper);
    final presenceRepository =
        PresenceRepository(databaseHelper: databaseHelper);

    await scoutRepository.save(const Scout(
      id: 'scout-1',
      nom: 'Dupont',
      prenom: 'Jean',
      qrToken: 'scout_token_1',
      statut: ScoutStatus.actif,
      createdAt: 1,
    ));
    await reunionRepository.create(const Reunion(
      id: 'reunion-1',
      date: '2026-09-05',
      heureDebut: '15:00',
      totalScouts: 1,
      statut: ReunionStatus.ouverte,
      createdAt: 1,
    ));

    const presence = Presence(
      id: 'presence-1',
      reunionId: 'reunion-1',
      scoutId: 'scout-1',
      scannedAt: '2026-09-05T15:01:00.000',
    );

    expect(await presenceRepository.add(presence), isTrue);
    expect(await presenceRepository.add(presence), isFalse);
    expect(await presenceRepository.countForReunion('reunion-1'), 1);
  });

  test('prevents two open reunions', () async {
    final repository = ReunionRepository(databaseHelper: databaseHelper);
    const first = Reunion(
      id: 'reunion-1',
      date: '2026-09-05',
      heureDebut: '15:00',
      totalScouts: 0,
      statut: ReunionStatus.ouverte,
      createdAt: 1,
    );
    const second = Reunion(
      id: 'reunion-2',
      date: '2026-09-06',
      heureDebut: '15:00',
      totalScouts: 0,
      statut: ReunionStatus.ouverte,
      createdAt: 2,
    );

    await repository.create(first);
    await expectLater(repository.create(second), throwsStateError);
  });

  test('enables foreign keys for target tables', () async {
    final db = await databaseHelper.database;
    final result = await db.rawQuery('PRAGMA foreign_keys');

    expect(result.single.values.single, 1);
  });

  test('migrates a version 4 database to the patrol schema', () async {
    final path = '${temporaryDirectory.path}/test.db';
    final legacyDatabase = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE scouts (
              id TEXT PRIMARY KEY,
              nom TEXT NOT NULL DEFAULT '',
              prenom TEXT NOT NULL,
              qr_token TEXT NOT NULL UNIQUE,
              statut TEXT NOT NULL DEFAULT 'actif',
              created_at INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
    await legacyDatabase.close();

    final db = await databaseHelper.database;
    final columns = await db.rawQuery('PRAGMA table_info(scouts)');
    final columnNames = columns.map((column) => column['name']).toSet();
    expect(columnNames, contains('patrouille_id'));
    expect(columnNames, contains('role_patrouille'));

    final scoutRepository = ScoutRepository(databaseHelper: databaseHelper);
    await scoutRepository.create(const Scout(
      id: 'scout-1',
      nom: 'Dupont',
      prenom: 'Jean',
      qrToken: 'scout_token_1',
      statut: ScoutStatus.actif,
      createdAt: 1,
    ));
    await db.insert('patrouilles', {
      'id': 'patrouille-1',
      'nom': 'Aigles',
      'created_at': 1,
    });
    await scoutRepository.assignPatrouille(
      scoutId: 'scout-1',
      patrouilleId: 'patrouille-1',
    );
  });
}
