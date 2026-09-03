import 'dart:io';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../repositories/patrouille_repository.dart';
import '../repositories/scout_repository.dart';
import '../theme.dart';
import 'scout_profile_screen.dart';

const List<String> kPatrouilleColors = [
  '#1F3D2E', // forêt
  '#C1440E', // ember
  '#A98F5E', // khaki
  '#2E5266', // bleu nuit
  '#7A3B3B', // bordeaux
  '#4A6D3F', // vert clair
  '#1F3D2E', // forêt
  '#C1440E', // ember
  '#A98F5E', // khaki
  '#2E5266', // bleu nuit
  '#7A3B3B', // bordeaux
  '#4A6D3F', // vert clair
  '#2A9D8F', // vert d'eau
  '#E9C46A', // ocre / moutarde
  '#D4A373', // terre / cuir
  '#405D72', // bleu orage
  '#6B5B95', // violet totem
  '#D64045', // rouge vermillon
  '#264653', // bleu pétrole
  '#588157', // vert sauge
  '#E76F51', // corail / terre cuite
  '#8C7A6B', // granit / roc
];

class PatrouilleScreen extends StatefulWidget {
  final VoidCallback? onChanged;
  const PatrouilleScreen({super.key, this.onChanged});

  @override
  State<PatrouilleScreen> createState() => _PatrouilleScreenState();
}

class _PatrouilleScreenState extends State<PatrouilleScreen> {
  final _patrouilleRepo = PatrouilleRepository();
  final _scoutRepo = ScoutRepository();

  List<Patrouille> _patrouilles = [];
  Map<String, List<Scout>> _membersByPatrouille = {};
  List<Scout> _sansPatrouille = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final patrouilles = await _patrouilleRepo.getAll();
    final membersMap = <String, List<Scout>>{};
    for (final p in patrouilles) {
      membersMap[p.id] = await _scoutRepo.getForPatrouille(p.id);
    }
    final sans = await _scoutRepo.getSansPatrouille();
    if (!mounted) return;
    setState(() {
      _patrouilles = patrouilles;
      _membersByPatrouille = membersMap;
      _sansPatrouille = sans;
      _loading = false;
    });
    widget.onChanged?.call();
  }

  Future<void> _createOrEditPatrouille({Patrouille? existing}) async {
    final nameController = TextEditingController(text: existing?.nom ?? '');
    String selectedColor = existing?.couleur ?? kPatrouilleColors.first;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Nouvelle patrouille' : 'Renommer la patrouille'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'Ex : Aigles, Loups...'),
                autofocus: true,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: kPatrouilleColors.map((hex) {
                  final color = Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
                  final selected = selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = hex),
                    child: CircleAvatar(
                      backgroundColor: color,
                      radius: 16,
                      child: selected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );

    if (result != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;

    try {
      if (existing == null) {
        await _patrouilleRepo.save(Patrouille(
          id: 'patrouille-${DateTime.now().microsecondsSinceEpoch}',
          nom: name,
          couleur: selectedColor,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
      } else {
        await _patrouilleRepo.rename(existing.id, name, selectedColor);
      }
      await _load();
    } on StateError catch (e) {
      _message(e.message);
    }
  }

  Future<void> _deletePatrouille(Patrouille p) async {
    final members = _membersByPatrouille[p.id] ?? [];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer "${p.nom}" ?'),
        content: Text(members.isEmpty
            ? 'Cette patrouille sera supprimée.'
            : '${members.length} jeune(s) actuellement dans cette patrouille repasseront "sans patrouille".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm == true) {
      await _patrouilleRepo.delete(p.id);
      await _load();
    }
  }

  void _message(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _colorOf(String? hex) {
    if (hex == null) return AppColors.khaki;
    return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ..._patrouilles.map((p) {
              final members = _membersByPatrouille[p.id] ?? [];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  leading: CircleAvatar(backgroundColor: _colorOf(p.couleur), radius: 10),
                  title: Text(p.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${members.length} membre(s)'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _createOrEditPatrouille(existing: p);
                      if (v == 'delete') _deletePatrouille(p);
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'edit', child: Text('Renommer')),
                      PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                    ],
                  ),
                  children: members.isEmpty
                      ? [const Padding(padding: EdgeInsets.all(14), child: Text('Aucun membre pour l\'instant.'))]
                      : members.map((s) => _scoutTile(s)).toList(),
                ),
              );
            }),
            if (_sansPatrouille.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Sans patrouille (${_sansPatrouille.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
              Card(
                margin: const EdgeInsets.only(top: 6),
                child: Column(children: _sansPatrouille.map((s) => _scoutTile(s)).toList()),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createOrEditPatrouille(),
        icon: const Icon(Icons.add),
        label: const Text('Patrouille'),
        backgroundColor: AppColors.ember,
      ),
    );
  }

  Widget _scoutTile(Scout s) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.mossLight,
        backgroundImage: s.photoPath != null ? FileImage(File(s.photoPath!)) as ImageProvider : null,
        child: s.photoPath == null ? Text(s.prenom.isNotEmpty ? s.prenom[0] : '?') : null,
      ),
      title: Text(s.displayName),
      trailing: s.rolePatrouille == RolePatrouille.membre
          ? null
          : Chip(
              label: Text(s.rolePatrouille.shortLabel, style: const TextStyle(fontSize: 11, color: Colors.white)),
              backgroundColor: AppColors.forest,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ScoutProfileScreen(scout: s)));
        _load();
      },
    );
  }
}
