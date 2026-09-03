import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/models.dart';
import '../repositories/presence_repository.dart';
import '../repositories/reunion_repository.dart';
import '../repositories/scout_repository.dart';
import '../theme.dart';

enum _FlashType { ok, duplicate, unknown, inactive, error }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  final _scannerController = MobileScannerController();
  final _reunionRepository = ReunionRepository();
  final _scoutRepository = ScoutRepository();
  final _presenceRepository = PresenceRepository();

  Reunion? _reunion;
  List<Scout> _scouts = [];
  Map<String, Presence> _presences = {};
  bool _loading = true;
  bool _cameraReady = false;
  String? _cameraMessage;
  final Set<String> _savingIds = {};
  String? _lastScannedToken;
  DateTime? _lastScanTime;
  Timer? _flashTimer;
  bool _flashVisible = false;
  _FlashType _flashType = _FlashType.ok;
  String _flashText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _prepareCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
      _prepareCamera(restart: true);
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _scannerController.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flashTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final reunion = await _reunionRepository.getOpen();
      if (reunion == null) {
        if (mounted) {
          setState(() {
            _reunion = null;
            _loading = false;
          });
        }
        return;
      }
      final scouts = await _scoutRepository.getAll(includeInactive: false);
      final presences = await _presenceRepository.getForReunion(reunion.id);
      if (!mounted) return;
      setState(() {
        _reunion = reunion;
        _scouts = scouts;
        _presences = {
          for (final presence in presences) presence.scoutId: presence
        };
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _showMessage('Impossible de charger la réunion.');
      }
    }
  }

  Future<void> _prepareCamera({bool restart = false}) async {
    try {
      final status = await Permission.camera.request();
      if (!mounted) return;
      setState(() {
        _cameraReady = status.isGranted;
        _cameraMessage = status.isGranted
            ? null
            : 'Autorise la caméra pour scanner un badge.';
      });
      if (status.isGranted && restart) {
        await _scannerController.start();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cameraReady = true;
          _cameraMessage = null;
        });
        if (restart) await _scannerController.start();
      }
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final token = capture.barcodes.firstOrNull?.rawValue;
    if (token == null || _reunion == null) return;
    final now = DateTime.now();
    if (token == _lastScannedToken &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!).inMilliseconds < 1800) {
      return;
    }
    _lastScannedToken = token;
    _lastScanTime = now;

    final scout = await _scoutRepository.findByQrToken(token);
    if (!mounted) return;
    if (scout == null) {
      _showFlash(_FlashType.unknown, 'QR code inconnu');
      return;
    }
    if (scout.statut != ScoutStatus.actif) {
      _showFlash(_FlashType.inactive, 'Ce scout est inactif');
      return;
    }
    if (_presences.containsKey(scout.id) || _savingIds.contains(scout.id)) {
      _showFlash(_FlashType.duplicate, '${scout.displayName} est déjà présent');
      return;
    }
    await _markPresent(scout);
  }

  Future<void> _markPresent(Scout scout) async {
    final reunion = _reunion;
    if (reunion == null || _savingIds.contains(scout.id)) return;
    _savingIds.add(scout.id);
    final presence = Presence(
      id: '${reunion.id}::${scout.id}',
      reunionId: reunion.id,
      scoutId: scout.id,
      scannedAt: DateTime.now().toIso8601String(),
    );
    setState(() => _presences[scout.id] = presence);
    try {
      final inserted = await _presenceRepository.add(presence);
      if (!mounted) return;
      if (!inserted) {
        await _load();
        _showFlash(
            _FlashType.duplicate, '${scout.displayName} est déjà présent');
      } else {
        _showFlash(_FlashType.ok, '${scout.displayName} est présent');
        HapticFeedback.mediumImpact();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _presences.remove(scout.id));
        _showFlash(_FlashType.error, 'Impossible d’enregistrer la présence');
      }
    } finally {
      _savingIds.remove(scout.id);
    }
  }

  Future<void> _toggleManual(Scout scout) async {
    final reunion = _reunion;
    if (reunion == null || _savingIds.contains(scout.id)) return;
    if (_presences.containsKey(scout.id)) {
      _savingIds.add(scout.id);
      try {
        await _presenceRepository.remove(
            reunionId: reunion.id, scoutId: scout.id);
        if (mounted) setState(() => _presences.remove(scout.id));
      } catch (_) {
        _showMessage('Impossible de retirer la présence.');
      } finally {
        _savingIds.remove(scout.id);
      }
    } else {
      await _markPresent(scout);
    }
  }

  void _showFlash(_FlashType type, String text) {
    if (!mounted) return;
    _flashTimer?.cancel();
    setState(() {
      _flashType = type;
      _flashText = text;
      _flashVisible = true;
    });
    _flashTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _flashVisible = false);
    });
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final reunion = _reunion;
    if (reunion == null) return _emptyState();
    final total = _scouts.length;
    final present = _presences.length;
    final rate = total == 0 ? 0 : present * 100 / total;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
              child: ListTile(
            leading: const Icon(Icons.event, color: AppColors.forest),
            title: Text(DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                .format(DateTime.parse(reunion.date))),
            subtitle: Text(
                '${reunion.heureDebut} • ${reunion.compteRendu ?? 'Réunion en cours'}'),
          )),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _cameraReady
                      ? MobileScanner(
                          controller: _scannerController,
                          onDetect: _onDetect,
                          errorBuilder: (context, error, child) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.videocam_off_outlined,
                                      size: 48),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'La caméra est momentanément indisponible.',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _prepareCamera(restart: true),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Réactiver la caméra'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : _cameraFallback(),
                ),
                IgnorePointer(
                    child: Center(
                        child: FractionallySizedBox(
                  widthFactor: .7,
                  heightFactor: .55,
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                    border: Border.all(color: AppColors.khakiLight, width: 3),
                    borderRadius: BorderRadius.circular(12),
                  )),
                ))),
                if (_flashVisible)
                  Container(
                    color: _flashColor(),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(16),
                    child: Text(_flashText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _statCard('$present', 'Présents')),
            const SizedBox(width: 8),
            Expanded(child: _statCard('${total - present}', 'Absents')),
            const SizedBox(width: 8),
            Expanded(child: _statCard('${rate.toStringAsFixed(1)} %', 'Taux')),
          ]),
          const SizedBox(height: 12),
          Card(
              child: Column(
                  children: _scouts.map((scout) {
            final isPresent = _presences.containsKey(scout.id);
            return ListTile(
              title: Text(scout.displayName),
              subtitle: Text(isPresent ? 'Présent' : 'Absent'),
              trailing: TextButton(
                onPressed: () => _toggleManual(scout),
                child: Text(isPresent ? 'Retirer' : 'Marquer présent'),
              ),
            );
          }).toList())),
        ],
      ),
    );
  }

  Widget _emptyState() => const Center(
          child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_busy, size: 56, color: AppColors.khaki),
          SizedBox(height: 12),
          Text('Aucune réunion ouverte.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
              'Crée une réunion dans l’onglet Historique avant de commencer l’appel.',
              textAlign: TextAlign.center),
        ]),
      ));

  Widget _cameraFallback() => Center(
          child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.no_photography_outlined, size: 48),
          const SizedBox(height: 12),
          Text(_cameraMessage ?? 'Préparation de la caméra...',
              textAlign: TextAlign.center),
          if (_cameraMessage != null)
            OutlinedButton.icon(
              onPressed: _prepareCamera,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
        ]),
      ));

  Color _flashColor() {
    switch (_flashType) {
      case _FlashType.ok:
        return AppColors.moss.withValues(alpha: .94);
      case _FlashType.duplicate:
        return AppColors.khaki.withValues(alpha: .94);
      case _FlashType.unknown:
      case _FlashType.inactive:
      case _FlashType.error:
        return AppColors.danger.withValues(alpha: .94);
    }
  }

  Widget _statCard(String value, String label) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: AppColors.mossLight,
            borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.forest)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ]),
      );
}
