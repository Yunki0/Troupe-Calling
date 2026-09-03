import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../repositories/presence_repository.dart';
import '../repositories/reunion_repository.dart';
import '../repositories/scout_repository.dart';
import '../theme.dart';
import 'reunion_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback onReunionChanged;

  const HistoryScreen({super.key, required this.onReunionChanged});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _reunionRepository = ReunionRepository();
  final _presenceRepository = PresenceRepository();
  final _scoutRepository = ScoutRepository();
  List<Reunion> _reunions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reunions = await _reunionRepository.getAll();
      if (!mounted) return;
      setState(() {
        _reunions = reunions;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _message('Impossible de charger les réunions.');
      }
    }
  }

  Future<void> _createReunion() async {
    final result = await showDialog<_ReunionFormResult>(
      context: context,
      builder: (_) => const _CreateReunionDialog(),
    );
    if (result == null) return;

    try {
      final activeScouts =
          await _scoutRepository.getAll(includeInactive: false);
      if (!mounted) return;
      final reunion = Reunion(
        id: 'reunion-${DateTime.now().microsecondsSinceEpoch}',
        date: DateFormat('yyyy-MM-dd').format(result.date),
        heureDebut: result.startTime.format(context),
        compteRendu: result.notes.isEmpty ? null : result.notes,
        createdBy: 'Chef 1',
        totalScouts: activeScouts.length,
        statut: ReunionStatus.ouverte,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _reunionRepository.create(reunion);
      await _load();
      if (!mounted) return;
      widget.onReunionChanged();
      _message('Réunion ouverte.');
    } on StateError catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Impossible de créer la réunion.');
    }
  }

  Future<void> _finishReunion(Reunion reunion) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminer la réunion ?'),
        content: const Text(
            'Les présences resteront consultables dans l’historique.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Terminer')),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    try {
      await _reunionRepository.finish(
        reunion.id,
        heureFin: TimeOfDay.now().format(context),
      );
      await _load();
      if (!mounted) return;
      widget.onReunionChanged();
      _message('Réunion terminée.');
    } catch (_) {
      _message('Impossible de terminer la réunion.');
    }
  }

  void _message(String? text) {
    if (mounted && text != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Réunions',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.forest)),
              ),
              FilledButton.icon(
                onPressed: _createReunion,
                icon: const Icon(Icons.add),
                label: const Text('Créer'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator()))
          else if (_reunions.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                        'Aucune réunion. Crée la première réunion pour commencer l’appel.')))
          else
            ..._reunions.map(_reunionCard),
        ],
      ),
    );
  }

  Widget _reunionCard(Reunion reunion) {
    final open = reunion.statut == ReunionStatus.ouverte;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReunionDetailScreen(reunion: reunion),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                              .format(DateTime.parse(reunion.date)),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.forest),
                        ),
                      ),
                      Chip(
                        label: Text(open ? 'Ouverte' : 'Terminée'),
                        backgroundColor:
                            open ? AppColors.mossLight : Colors.black12,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                      '${reunion.heureDebut} → ${reunion.heureFin ?? 'en cours'}'),
                  if (reunion.compteRendu?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(reunion.compteRendu!),
                  ],
                  const SizedBox(height: 10),
                  FutureBuilder<int>(
                    future: _presenceRepository.countForReunion(reunion.id),
                    builder: (context, snapshot) {
                      final present = snapshot.data ?? 0;
                      final total = reunion.totalScouts;
                      final rate = total == 0 ? 0 : present * 100 / total;
                      return Text(
                          'Présents : $present / $total   •   Taux : ${rate.toStringAsFixed(1)} %');
                    },
                  ),
                ],
              ),
            ),
            if (open) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _finishReunion(reunion),
                  icon: const Icon(Icons.check),
                  label: const Text('Terminer'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReunionFormResult {
  final DateTime date;
  final TimeOfDay startTime;
  final String notes;

  const _ReunionFormResult(this.date, this.startTime, this.notes);
}

class _CreateReunionDialog extends StatefulWidget {
  const _CreateReunionDialog();

  @override
  State<_CreateReunionDialog> createState() => _CreateReunionDialogState();
}

class _CreateReunionDialogState extends State<_CreateReunionDialog> {
  DateTime _date = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  Future<void> _pickTime() async {
    final time =
        await showTimePicker(context: context, initialTime: _startTime);
    if (time != null && mounted) setState(() => _startTime = time);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle réunion'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle:
                  Text(DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_date)),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Heure de début'),
              subtitle: Text(_startTime.format(context)),
              onTap: _pickTime,
            ),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Activité / compte rendu'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _ReunionFormResult(_date, _startTime, _notesController.text.trim()),
          ),
          child: const Text('Ouvrir'),
        ),
      ],
    );
  }
}
