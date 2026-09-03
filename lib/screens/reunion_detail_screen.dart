import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../repositories/presence_repository.dart';
import '../repositories/scout_repository.dart';
import '../theme.dart';

class ReunionDetailScreen extends StatefulWidget {
  final Reunion reunion;

  const ReunionDetailScreen({super.key, required this.reunion});

  @override
  State<ReunionDetailScreen> createState() => _ReunionDetailScreenState();
}

class _ReunionDetailScreenState extends State<ReunionDetailScreen> {
  final _scoutRepository = ScoutRepository();
  final _presenceRepository = PresenceRepository();
  List<Scout> _scouts = [];
  List<Presence> _presences = [];
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final scouts = await _scoutRepository.getAll();
      final presences =
          await _presenceRepository.getForReunion(widget.reunion.id);
      if (!mounted) return;
      setState(() {
        _scouts = scouts;
        _presences = presences;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _message('Impossible de charger le détail de la réunion.');
      }
    }
  }

  Future<void> _exportCsv() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final presenceByScout = {
        for (final presence in _presences) presence.scoutId: presence,
      };
      final buffer = StringBuffer('Nom,Prénom,Statut,Heure de présence\n');
      for (final scout in _scouts) {
        final presence = presenceByScout[scout.id];
        final time = presence == null
            ? ''
            : DateFormat('HH:mm').format(DateTime.parse(presence.scannedAt));
        buffer.writeln([
          _csvCell(scout.nom),
          _csvCell(scout.prenom),
          _csvCell(presence == null ? 'Absent' : 'Présent'),
          _csvCell(time),
        ].join(','));
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/reunion_${widget.reunion.id}.csv');
      await file.writeAsString(buffer.toString());
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Présences du ${widget.reunion.date}',
      );
    } catch (_) {
      _message('Impossible d’exporter la réunion.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _csvCell(String value) {
    final safeValue = RegExp(r'^[=+\-@]').hasMatch(value) ? "'$value" : value;
    return '"${safeValue.replaceAll('"', '""')}"';
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final presenceIds = _presences.map((presence) => presence.scoutId).toSet();
    final activeScouts =
        _scouts.where((scout) => scout.statut == ScoutStatus.actif).toList();
    final presentScouts =
        _scouts.where((scout) => presenceIds.contains(scout.id)).toList();
    final absentScouts =
        activeScouts.where((scout) => !presenceIds.contains(scout.id)).toList();
    final total = widget.reunion.totalScouts;
    final rate = total == 0 ? 0 : _presences.length * 100 / total;

    return Scaffold(
      appBar: AppBar(title: const Text('Détail de la réunion')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text(
                DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                    .format(DateTime.parse(widget.reunion.date)),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forest)),
            Text(
                '${widget.reunion.heureDebut} → ${widget.reunion.heureFin ?? 'en cours'}'),
            if (widget.reunion.compteRendu?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(widget.reunion.compteRendu!))),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _statCard('${_presences.length}', 'Présents')),
              const SizedBox(width: 8),
              Expanded(child: _statCard('${absentScouts.length}', 'Absents')),
              const SizedBox(width: 8),
              Expanded(
                  child: _statCard('${rate.toStringAsFixed(1)} %', 'Taux')),
            ]),
            const SizedBox(height: 16),
            _section('Présents', presentScouts, true),
            const SizedBox(height: 12),
            _section('Absents', absentScouts, false),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _exporting ? null : _exportCsv,
              icon: const Icon(Icons.ios_share),
              label:
                  Text(_exporting ? 'Export en cours...' : 'Exporter en CSV'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Scout> scouts, bool present) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.forest))),
          if (scouts.isEmpty)
            const Padding(
                padding: EdgeInsets.all(14), child: Text('Aucun scout.'))
          else
            ...scouts.map((scout) {
              final presence = _presences.cast<Presence?>().firstWhere(
                    (item) => item?.scoutId == scout.id,
                    orElse: () => null,
                  );
              return ListTile(
                leading: Icon(present ? Icons.check_circle : Icons.cancel,
                    color: present ? AppColors.moss : AppColors.danger),
                title: Text(scout.displayName),
                subtitle: present && presence != null
                    ? Text(DateFormat('HH:mm')
                        .format(DateTime.parse(presence.scannedAt)))
                    : null,
              );
            }),
        ],
      ),
    );
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
