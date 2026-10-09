import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:troupe_manager/db/database_helper.dart';
import 'package:troupe_manager/models/models.dart';
import 'package:troupe_manager/repositories/scout_repository.dart';
import 'package:troupe_manager/services/backup_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('rejects photo paths outside the backup photo directory', () async {
    final temporaryDirectory =
        await Directory.systemTemp.createTemp('troupe_backup_test_');
    final archive = Archive()
      ..addFile(ArchiveFile('appel_scout.db', 3, [1, 2, 3]))
      ..addFile(ArchiveFile('photos/../../outside.jpg', 1, [0]));
    final zipBytes = ZipEncoder().encode(archive);
    final zipFile = File('${temporaryDirectory.path}/unsafe.zip');
    await zipFile.writeAsBytes(zipBytes, flush: true);

    try {
      await expectLater(
        _service(
          DatabaseHelper.forTesting(
            databaseFactory: databaseFactoryFfi,
            databasePath: '${temporaryDirectory.path}/untouched.db',
          ),
          temporaryDirectory,
        ).restoreBackupArchive(zipFile),
        throwsA(isA<StateError>()),
      );
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('rejects an invalid database without changing the live database',
      () async {
    final temporaryDirectory =
        await Directory.systemTemp.createTemp('troupe_backup_test_');
    final databaseHelper = _databaseHelper(temporaryDirectory, 'live.db');
    final repository = ScoutRepository(databaseHelper: databaseHelper);
    await repository.create(_scout('live-scout'));
    final archive = Archive()
      ..addFile(ArchiveFile('appel_scout.db', 3, [1, 2, 3]));
    final zipFile = await _writeArchive(temporaryDirectory, archive);
    final service = _service(databaseHelper, temporaryDirectory);

    try {
      await expectLater(
        service.restoreBackupArchive(zipFile),
        throwsA(isA<StateError>()),
      );
      expect((await repository.getAll()).single.id, 'live-scout');
    } finally {
      await databaseHelper.close();
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('restores database and photos as one staged operation', () async {
    final temporaryDirectory =
        await Directory.systemTemp.createTemp('troupe_backup_test_');
    final liveHelper = _databaseHelper(temporaryDirectory, 'live.db');
    final sourceHelper = _databaseHelper(temporaryDirectory, 'source.db');
    final liveRepository = ScoutRepository(databaseHelper: liveHelper);
    final sourceRepository = ScoutRepository(databaseHelper: sourceHelper);
    await liveRepository.create(_scout('old-scout'));
    await sourceRepository.create(_scout('restored-scout'));

    final photosDirectory = Directory('${temporaryDirectory.path}/photos')
      ..createSync();
    await File('${photosDirectory.path}/old.jpg').writeAsBytes([1]);
    final sourceBytes = await File(await sourceHelper.databasePath).readAsBytes();
    final archive = Archive()
      ..addFile(ArchiveFile('appel_scout.db', sourceBytes.length, sourceBytes))
      ..addFile(ArchiveFile('photos/new.jpg', 2, [2, 3]));
    final zipFile = await _writeArchive(temporaryDirectory, archive);
    final service = _service(liveHelper, temporaryDirectory);

    try {
      await service.restoreBackupArchive(zipFile);

      expect(
        (await ScoutRepository(databaseHelper: liveHelper).getAll())
            .map((scout) => scout.id),
        ['restored-scout'],
      );
      expect(await File('${photosDirectory.path}/old.jpg').exists(), isFalse);
      expect(
        await File('${photosDirectory.path}/new.jpg').readAsBytes(),
        [2, 3],
      );
    } finally {
      await liveHelper.close();
      await sourceHelper.close();
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('rolls the database back when installing the photo directory fails',
      () async {
    final temporaryDirectory =
        await Directory.systemTemp.createTemp('troupe_backup_test_');
    final liveHelper = _databaseHelper(temporaryDirectory, 'live.db');
    final sourceHelper = _databaseHelper(temporaryDirectory, 'source.db');
    await ScoutRepository(databaseHelper: liveHelper)
        .create(_scout('old-scout'));
    await ScoutRepository(databaseHelper: sourceHelper)
        .create(_scout('restored-scout'));

    final photosPath = '${temporaryDirectory.path}/photos';
    final conflictingPhotoPath = File(photosPath)
      ..writeAsStringSync('not a directory');
    final sourceBytes = await File(await sourceHelper.databasePath).readAsBytes();
    final archive = Archive()
      ..addFile(ArchiveFile('appel_scout.db', sourceBytes.length, sourceBytes))
      ..addFile(ArchiveFile('photos/new.jpg', 1, [2]));
    final zipFile = await _writeArchive(temporaryDirectory, archive);
    final service = BackupService(
      databaseHelper: liveHelper,
      photosDirectoryProvider: () async => Directory(photosPath),
      temporaryDirectoryProvider: () async => temporaryDirectory,
    );

    try {
      await expectLater(
        service.restoreBackupArchive(zipFile),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        (await ScoutRepository(databaseHelper: liveHelper).getAll()).single.id,
        'old-scout',
      );
      expect(await conflictingPhotoPath.readAsString(), 'not a directory');
    } finally {
      await liveHelper.close();
      await sourceHelper.close();
      await temporaryDirectory.delete(recursive: true);
    }
  });
}

DatabaseHelper _databaseHelper(Directory directory, String fileName) =>
    DatabaseHelper.forTesting(
      databaseFactory: databaseFactoryFfi,
      databasePath: '${directory.path}/$fileName',
    );

BackupService _service(
  DatabaseHelper databaseHelper,
  Directory directory,
) =>
    BackupService(
      databaseHelper: databaseHelper,
      photosDirectoryProvider: () async => Directory('${directory.path}/photos'),
      temporaryDirectoryProvider: () async => directory,
    );

Scout _scout(String id) => Scout(
      id: id,
      nom: 'Scout',
      prenom: id,
      qrToken: 'token-$id',
      statut: ScoutStatus.actif,
      createdAt: 1,
    );

Future<File> _writeArchive(Directory directory, Archive archive) async {
  final zipBytes = ZipEncoder().encode(archive);
  final zipFile = File('${directory.path}/backup.zip');
  await zipFile.writeAsBytes(zipBytes, flush: true);
  return zipFile;
}
