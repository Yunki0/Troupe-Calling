import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:troupe_manager/db/database_helper.dart';
import 'package:troupe_manager/models/models.dart';
import 'package:troupe_manager/repositories/dashboard_repository.dart';
import 'package:troupe_manager/repositories/patrouille_repository.dart';
import 'package:troupe_manager/repositories/presence_repository.dart';
import 'package:troupe_manager/repositories/reunion_repository.dart';
import 'package:troupe_manager/repositories/scout_repository.dart';

void main() {
  late Directory temporaryDirectory;
  late DatabaseHelper databaseHelper;
  late ScoutRepository scoutRepository;
  late ReunionRepository reunionRepository;
  late PresenceRepository presenceRepository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'dashboard_repository_test_',
    );
    databaseHelper = DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: '${temporaryDirectory.path}/test.db',
    );
    scoutRepository = ScoutRepository(databaseHelper: databaseHelper);
    reunionRepository = ReunionRepository(databaseHelper: databaseHelper);
    presenceRepository = PresenceRepository(databaseHelper: databaseHelper);
  });

  tearDown(() async {
    await databaseHelper.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'uses each reunion roster snapshot for recent attendance rates',
    () async {
      for (var i = 1; i <= 4; i++) {
        await scoutRepository.create(
          Scout(
            id: 'scout-$i',
            nom: 'Nom$i',
            prenom: 'Scout$i',
            qrToken: 'token-$i',
            statut: ScoutStatus.actif,
            createdAt: i,
          ),
        );
      }

      await _createFinishedReunion(
        reunionRepository,
        id: 'reunion-older',
        date: '2026-09-01',
        totalScouts: 4,
        createdAt: 1,
      );
      await _createFinishedReunion(
        reunionRepository,
        id: 'reunion-recent',
        date: '2026-09-08',
        totalScouts: 2,
        createdAt: 2,
      );
      for (var i = 1; i <= 3; i++) {
        await _addPresence(
          presenceRepository,
          reunionId: 'reunion-older',
          scoutId: 'scout-$i',
        );
      }
      await _addPresence(
        presenceRepository,
        reunionId: 'reunion-recent',
        scoutId: 'scout-1',
      );

      final data = await DashboardRepository(
        scoutRepository: scoutRepository,
        patrouilleRepository: PatrouilleRepository(
          databaseHelper: databaseHelper,
        ),
        reunionRepository: reunionRepository,
        presenceRepository: presenceRepository,
      ).load(now: DateTime(2026, 9, 9));

      expect(data.tauxDerniereReunion, 50);
      expect(data.tauxMoyenRecent, 62.5);
      expect(data.reunionsConsiderees, 2);
    },
  );

  test('exposes the open reunion for the dashboard primary action', () async {
    await reunionRepository.create(
      const Reunion(
        id: 'reunion-open',
        date: '2026-09-09',
        heureDebut: '15:00',
        totalScouts: 0,
        statut: ReunionStatus.ouverte,
        createdAt: 1,
      ),
    );

    final data = await DashboardRepository(
      scoutRepository: scoutRepository,
      patrouilleRepository: PatrouilleRepository(
        databaseHelper: databaseHelper,
      ),
      reunionRepository: reunionRepository,
      presenceRepository: presenceRepository,
    ).load(now: DateTime(2026, 9, 9));

    expect(data.reunionOuverte?.id, 'reunion-open');
  });

  test(
    'calculates leap-day birthdays and ignores malformed and inactive dates',
    () async {
      await scoutRepository.create(
        const Scout(
          id: 'leap-scout',
          nom: 'Jour',
          prenom: 'Né',
          qrToken: 'leap-token',
          statut: ScoutStatus.actif,
          createdAt: 1,
          dateNaissance: '2000-02-29',
        ),
      );
      await scoutRepository.create(
        const Scout(
          id: 'invalid-scout',
          nom: 'Invalide',
          prenom: 'Date',
          qrToken: 'invalid-token',
          statut: ScoutStatus.actif,
          createdAt: 2,
          dateNaissance: '2020-02-30',
        ),
      );
      await scoutRepository.create(
        const Scout(
          id: 'short-date-scout',
          nom: 'Court',
          prenom: 'Date',
          qrToken: 'short-date-token',
          statut: ScoutStatus.actif,
          createdAt: 3,
          dateNaissance: '2000',
        ),
      );
      await scoutRepository.create(
        const Scout(
          id: 'inactive-scout',
          nom: 'Inactif',
          prenom: 'Scout',
          qrToken: 'inactive-token',
          statut: ScoutStatus.inactif,
          createdAt: 4,
          dateNaissance: '2000-02-22',
        ),
      );

      final data = await DashboardRepository(
        scoutRepository: scoutRepository,
        patrouilleRepository: PatrouilleRepository(
          databaseHelper: databaseHelper,
        ),
        reunionRepository: reunionRepository,
        presenceRepository: presenceRepository,
      ).load(now: DateTime(2023, 2, 20), birthdayWindowDays: 10);

      expect(data.anniversaires, hasLength(1));
      expect(data.anniversaires.single.scout.id, 'leap-scout');
      expect(data.anniversaires.single.nextBirthday, DateTime(2023, 3, 1));
      expect(data.anniversaires.single.daysUntil, 9);
      expect(data.anniversaires.single.turningAge, 23);
    },
  );
}

Future<void> _createFinishedReunion(
  ReunionRepository repository, {
  required String id,
  required String date,
  required int totalScouts,
  required int createdAt,
}) {
  return repository.create(
    Reunion(
      id: id,
      date: date,
      heureDebut: '15:00',
      heureFin: '17:00',
      totalScouts: totalScouts,
      statut: ReunionStatus.terminee,
      createdAt: createdAt,
    ),
  );
}

Future<void> _addPresence(
  PresenceRepository repository, {
  required String reunionId,
  required String scoutId,
}) async {
  await repository.add(
    Presence(
      id: '$reunionId::$scoutId',
      reunionId: reunionId,
      scoutId: scoutId,
      scannedAt: '2026-09-08T15:01:00.000',
    ),
  );
}
