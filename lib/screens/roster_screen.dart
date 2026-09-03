import 'dart:io';

import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/models.dart';
import '../repositories/patrouille_repository.dart';
import '../repositories/scout_repository.dart';
import '../theme.dart';
import 'patrouille_screen.dart';
import 'scout_profile_screen.dart';

class RosterScreen extends StatefulWidget {
  final ValueChanged<String> onTroopNameChanged;
  final VoidCallback onRosterChanged;

  const RosterScreen({
    super.key,
    required this.onTroopNameChanged,
    required this.onRosterChanged,
  });

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  final _repository = ScoutRepository();
  final _patrouilleRepository = PatrouilleRepository();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _troopController = TextEditingController();
  final _searchController = TextEditingController();
  List<Scout> _scouts = [];
  Map<String, Patrouille> _patrouillesById = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refreshSearch);
    _load();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _troopController.dispose();
    _searchController
      ..removeListener(_refreshSearch)
      ..dispose();
    super.dispose();
  }

  void _refreshSearch() => setState(() {});

  Future<void> _load() async {
    try {
      final scouts = await _repository.getAll();
      final patrouilles = await _patrouilleRepository.getAll();
      final troopName = await DatabaseHelper.instance.getSetting('troopName');
      if (!mounted) return;
      setState(() {
        _scouts = scouts;
        _patrouillesById = {for (final p in patrouilles) p.id: p};
        _troopController.text = troopName ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _showMessage('Impossible de charger les scouts.');
      }
    }
  }

  String _genToken() => 'scout_${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _addScout() async {
    final prenom = _firstNameController.text.trim();
    final nom = _lastNameController.text.trim();
    if (prenom.isEmpty || nom.isEmpty) {
      _showMessage('Renseigne le prénom et le nom.');
      return;
    }
    final scout = Scout(
      id: 'scout-id-${DateTime.now().microsecondsSinceEpoch}',
      nom: nom,
      prenom: prenom,
      qrToken: _genToken(),
      statut: ScoutStatus.actif,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await _repository.save(scout);
      if (!mounted) return;
      _firstNameController.clear();
      _lastNameController.clear();
      await _load();
      if (!mounted) return;
      widget.onRosterChanged();
      _showMessage('${scout.displayName} ajouté(e).');
    } catch (_) {
      _showMessage('Impossible d’ajouter ce scout.');
    }
  }

  Future<void> _toggleStatus(Scout scout) async {
    final newStatus = scout.statut == ScoutStatus.actif
        ? ScoutStatus.inactif
        : ScoutStatus.actif;
    try {
      await _repository.updateStatus(scout.id, newStatus);
      await _load();
      widget.onRosterChanged();
    } catch (_) {
      _showMessage('Impossible de modifier le statut.');
    }
  }

  Future<void> _editScout(Scout scout) async {
    final result = await showDialog<_ScoutEditResult>(
      context: context,
      builder: (_) => _EditScoutDialog(scout: scout),
    );
    if (result == null) return;
    try {
      await _repository.updateProfile(
        id: scout.id,
        prenom: result.prenom,
        nom: result.nom,
      );
      await _load();
      widget.onRosterChanged();
      _showMessage('Scout modifié. Son QR code reste inchangé.');
    } catch (_) {
      _showMessage('Impossible de modifier ce scout.');
    }
  }

  Future<void> _saveTroopName() async {
    final name = _troopController.text.trim();
    try {
      await DatabaseHelper.instance.setSetting('troopName', name);
      if (mounted) widget.onTroopNameChanged(name);
    } catch (_) {
      _showMessage('Impossible d’enregistrer le nom.');
    }
  }

  Future<void> _openProfile(Scout scout) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScoutProfileScreen(scout: scout)),
    );
    // La fiche technique / patrouille / photo ont pu changer.
    _load();
    widget.onRosterChanged();
  }

  Future<void> _openPatrouilles() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PatrouilleScreen()),
    );
    _load();
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Color _colorOf(String? hex) {
    if (hex == null) return AppColors.khaki;
    return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final scouts = _scouts
        .where((scout) => scout.displayName.toLowerCase().contains(query))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nom de la troupe',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.forest)),
                const SizedBox(height: 8),
                TextField(
                  controller: _troopController,
                  decoration:
                      const InputDecoration(hintText: 'Ex : Troupe des Aigles'),
                  onSubmitted: (_) => _saveTroopName(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.groups_2, color: AppColors.forest),
            title: const Text('Patrouilles', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_patrouillesById.isEmpty
                ? 'Aucune patrouille créée'
                : '${_patrouillesById.length} patrouille(s)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openPatrouilles,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ajouter un scout',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.forest)),
                const SizedBox(height: 8),
                TextField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Prénom'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Nom'),
                  onSubmitted: (_) => _addScout(),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addScout,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter et générer le QR code'),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'La fiche technique, la photo et la patrouille se complètent ensuite depuis la fiche du jeune.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Rechercher un scout',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (scouts.isEmpty)
          const Center(child: Text('Aucun scout trouvé.'))
        else
          ...scouts.map(_scoutTile),
      ],
    );
  }

  Widget _scoutTile(Scout scout) {
    final active = scout.statut == ScoutStatus.actif;
    final patrouille = scout.patrouilleId != null ? _patrouillesById[scout.patrouilleId] : null;

    return Card(
      child: ListTile(
        onTap: () => _openProfile(scout),
        leading: CircleAvatar(
          backgroundColor: active ? AppColors.mossLight : Colors.black12,
          backgroundImage: scout.photoPath != null
              ? FileImage(File(scout.photoPath!)) as ImageProvider
              : null,
          child: scout.photoPath == null
              ? Icon(Icons.qr_code_2, color: active ? AppColors.forest : Colors.black54)
              : null,
        ),
        title: Text(scout.displayName),
        subtitle: Row(
          children: [
            Text(active ? 'Actif' : 'Inactif'),
            if (patrouille != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _colorOf(patrouille.couleur).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _colorOf(patrouille.couleur)),
                ),
                child: Text(
                  scout.rolePatrouille == RolePatrouille.membre
                      ? patrouille.nom
                      : '${patrouille.nom} · ${scout.rolePatrouille.shortLabel}',
                  style: TextStyle(fontSize: 11, color: _colorOf(patrouille.couleur), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: active ? 'Désactiver' : 'Réactiver',
              onPressed: () => _toggleStatus(scout),
              icon: Icon(active ? Icons.toggle_on : Icons.toggle_off,
                  color: active ? AppColors.moss : Colors.black38, size: 32),
            ),
            IconButton(
              tooltip: 'Modifier',
              onPressed: () => _editScout(scout),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoutEditResult {
  final String prenom;
  final String nom;

  const _ScoutEditResult(this.prenom, this.nom);
}

class _EditScoutDialog extends StatefulWidget {
  final Scout scout;

  const _EditScoutDialog({required this.scout});

  @override
  State<_EditScoutDialog> createState() => _EditScoutDialogState();
}

class _EditScoutDialogState extends State<_EditScoutDialog> {
  late final TextEditingController _prenomController;
  late final TextEditingController _nomController;

  @override
  void initState() {
    super.initState();
    _prenomController = TextEditingController(text: widget.scout.prenom);
    _nomController = TextEditingController(text: widget.scout.nom);
  }

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le scout'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _prenomController,
            decoration: const InputDecoration(labelText: 'Prénom'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nomController,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final prenom = _prenomController.text.trim();
            final nom = _nomController.text.trim();
            if (prenom.isNotEmpty && nom.isNotEmpty) {
              Navigator.pop(context, _ScoutEditResult(prenom, nom));
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
