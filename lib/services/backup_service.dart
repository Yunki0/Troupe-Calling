import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../db/database_helper.dart';

/// Sauvegarde et restauration complète des données locales de l'app
/// (base SQLite + photos des scouts) dans une seule archive .zip.
///
/// L'app ne stocke rien ailleurs que sur l'appareil : sans cette
/// fonctionnalité, un téléphone perdu, cassé ou réinitialisé fait perdre
/// définitivement les fiches des jeunes, l'historique des présences et les
/// photos.
class BackupService {
  static const _dbEntryName = 'appel_scout.db';
  static const _photosPrefix = 'photos/';

  final DatabaseHelper _databaseHelper;
  final Future<Directory> Function() _photosDirectoryProvider;
  final Future<Directory> Function() _temporaryDirectoryProvider;

  BackupService({
    DatabaseHelper? databaseHelper,
    Future<Directory> Function()? photosDirectoryProvider,
    Future<Directory> Function()? temporaryDirectoryProvider,
  })  : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
        _photosDirectoryProvider =
            photosDirectoryProvider ?? _applicationPhotosDirectory,
        _temporaryDirectoryProvider =
            temporaryDirectoryProvider ?? getTemporaryDirectory;

  static Future<Directory> _applicationPhotosDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return Directory(path.join(docsDir.path, 'photos'));
  }

  /// Construit l'archive de sauvegarde et la place dans un fichier
  /// temporaire, prêt à être partagé (ex. via `share_plus`).
  Future<File> createBackupArchive() async {
    final dbPath = await _databaseHelper.databasePath;
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw StateError('Base de données introuvable.');
    }

    final archive = Archive();
    final dbBytes = await dbFile.readAsBytes();
    archive.addFile(ArchiveFile(_dbEntryName, dbBytes.length, dbBytes));

    final photosDir = await _photosDirectoryProvider();
    if (await photosDir.exists()) {
      await for (final entity in photosDir.list()) {
        if (entity is File) {
          final bytes = await entity.readAsBytes();
          final name = entity.uri.pathSegments.last;
          archive
              .addFile(ArchiveFile('$_photosPrefix$name', bytes.length, bytes));
        }
      }
    }

    final zipData = ZipEncoder().encode(archive);

    final tempDir = await _temporaryDirectoryProvider();
    final stamp =
        DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final outFile = File('${tempDir.path}/appel_scout_sauvegarde_$stamp.zip');
    await outFile.writeAsBytes(zipData, flush: true);
    return outFile;
  }

  /// Restaure une archive créée par [createBackupArchive]. Remplace la base
  /// et les photos actuelles : l'écran appelant doit avoir obtenu une
  /// confirmation explicite de l'utilisateur avant d'appeler cette méthode,
  /// l'opération étant irréversible.
  Future<void> restoreBackupArchive(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final dbEntries =
        archive.files.where((entry) => entry.name == _dbEntryName).toList();
    final dbEntry = dbEntries.firstOrNull;
    if (dbEntries.length != 1 || dbEntry == null || !dbEntry.isFile) {
      throw StateError(
          'Cette archive ne contient pas de base de données valide.');
    }

    final photoEntries = archive.files
        .where((entry) => entry.isFile && entry.name.startsWith(_photosPrefix))
        .toList();
    final photoNames = <String>{};
    for (final entry in photoEntries) {
      final fileName = entry.name.substring(_photosPrefix.length);
      if (fileName.isEmpty ||
          fileName == '.' ||
          fileName == '..' ||
          fileName.contains('/') ||
          fileName.contains(r'\') ||
          fileName.contains('\x00') ||
          !photoNames.add(fileName)) {
        throw StateError('Cette archive contient un chemin de photo invalide.');
      }
    }

    final dbPath = await _databaseHelper.databasePath;
    final dbFile = File(dbPath);
    final photosDir = await _photosDirectoryProvider();
    final transactionId = DateTime.now().microsecondsSinceEpoch;
    final stagedDb = File('$dbPath.restore-$transactionId.tmp');
    final previousDb = File('$dbPath.restore-$transactionId.bak');
    final stagedPhotos =
        Directory('${photosDir.path}.restore-$transactionId.tmp');
    final previousPhotos =
        Directory('${photosDir.path}.restore-$transactionId.bak');
    var previousDbMoved = false;
    var stagedDbInstalled = false;
    var previousPhotosMoved = false;
    var stagedPhotosInstalled = false;
    var liveReplacementStarted = false;
    var safeToDeleteBackups = true;

    try {
      await stagedDb.writeAsBytes(dbEntry.content as List<int>, flush: true);
      await _databaseHelper.validateDatabaseFile(stagedDb.path);

      await stagedPhotos.create(recursive: true);
      for (final entry in photoEntries) {
        final fileName = entry.name.substring(_photosPrefix.length);
        final outFile = File(path.join(stagedPhotos.path, fileName));
        await outFile.writeAsBytes(entry.content as List<int>, flush: true);
      }

      // Validate and stage every archive entry before closing the live database.
      liveReplacementStarted = true;
      await _databaseHelper.close();
      if (await dbFile.exists()) {
        await dbFile.rename(previousDb.path);
        previousDbMoved = true;
      }
      await stagedDb.rename(dbFile.path);
      stagedDbInstalled = true;

      if (await photosDir.exists()) {
        await photosDir.rename(previousPhotos.path);
        previousPhotosMoved = true;
      }
      await stagedPhotos.rename(photosDir.path);
      stagedPhotosInstalled = true;

      await _databaseHelper.database;
    } catch (error, stackTrace) {
      if (!liveReplacementStarted) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      try {
        await _databaseHelper.close();
        if (stagedDbInstalled && await dbFile.exists()) {
          await dbFile.delete();
        }
        if (previousDbMoved && await previousDb.exists()) {
          await previousDb.rename(dbFile.path);
        }
        if (stagedPhotosInstalled && await photosDir.exists()) {
          await photosDir.delete(recursive: true);
        }
        if (previousPhotosMoved && await previousPhotos.exists()) {
          await previousPhotos.rename(photosDir.path);
        }
        await _databaseHelper.database;
      } catch (rollbackError, rollbackStackTrace) {
        safeToDeleteBackups = false;
        Error.throwWithStackTrace(
          StateError(
            'La restauration a échoué et la récupération automatique a échoué : '
            '$rollbackError',
          ),
          rollbackStackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      if (await stagedDb.exists()) await stagedDb.delete();
      if (await stagedPhotos.exists()) {
        await stagedPhotos.delete(recursive: true);
      }
      if (safeToDeleteBackups) {
        if (await previousDb.exists()) await previousDb.delete();
        if (await previousPhotos.exists()) {
          await previousPhotos.delete(recursive: true);
        }
      }
    }
  }
}
