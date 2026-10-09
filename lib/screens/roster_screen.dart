import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';
import '../models/models.dart';
import '../repositories/patrouille_repository.dart';
import '../repositories/scout_repository.dart';
import '../services/backup_service.dart';
import '../theme.dart';
import 'patrouille_screen.dart';
import 'scout_profile_screen.dart';

class RosterScreen extends StatefulWidget {
  final VoidCallback onRosterChanged;

  const RosterScreen({
    super.key,
    required this.onRosterChanged,
  });

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

enum _RosterFilter { all, active, inactive }

enum _RosterAction { backup, restore }

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
  bool _loadFailed = false;
  _RosterFilter _filter = _RosterFilter.all;

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
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
        _showMessage('Impossible de charger les scouts.');
      }
    }
  }

  String _genToken() => 'scout_${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _showAddScoutDialog() async {
    final formKey = GlobalKey<FormState>();
    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Ajouter un jeune'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _firstNameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Prénom',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Renseigne le prénom.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Renseigne le nom.'
                    : null,
                onFieldSubmitted: (_) {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(dialogContext, true);
                  }
                },
              ),
              const SizedBox(height: 10),
              Text(
                'La fiche détaillée, la photo et la patrouille pourront être ajoutées ensuite.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (shouldAdd == true) await _addScout();
  }

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
      await _repository.create(scout);
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

  Future<void> _openProfile(Scout scout) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScoutProfileScreen(scout: scout)),
    );
    if (!mounted) return;
    // La fiche technique / patrouille / photo ont pu changer.
    _load();
    widget.onRosterChanged();
  }

  Future<void> _openPatrouilles() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PatrouilleScreen()),
    );
    if (!mounted) return;
    _load();
  }

  final _backupService = BackupService();
  bool _backingUp = false;
  bool _restoring = false;

  Future<void> _backupData() async {
    if (_backingUp) return;
    setState(() => _backingUp = true);
    try {
      final zipFile = await _backupService.createBackupArchive();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(zipFile.path)],
          text:
              'Sauvegarde — ${_troopController.text.trim().isEmpty ? "troupe" : _troopController.text.trim()}',
        ),
      );
    } catch (_) {
      _showMessage('Impossible de créer la sauvegarde.');
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _restoreData() async {
    if (_restoring) return;
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = picked?.path;
    if (path == null) return;
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurer cette sauvegarde ?'),
        content: const Text(
          'Toutes les données actuelles (scouts, patrouilles, réunions, photos) '
          'seront remplacées par celles de la sauvegarde. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _restoring = true);
    try {
      await _backupService.restoreBackupArchive(File(path));
      if (!mounted) return;
      // On ne tente pas de rafraîchir chaque écran individuellement : trop
      // d'état (nom de troupe, listes déjà chargées ailleurs dans l'app)
      // resterait incohérent avec la base qu'on vient de remplacer sous les
      // pieds de sqflite. Redémarrer l'app proprement est plus fiable.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Restauration terminée'),
          content: const Text(
            "Ferme complètement l'application (pas juste retour en arrière) "
            'puis rouvre-la pour voir tes données restaurées.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
    } catch (_) {
      _showMessage(
        "Impossible de restaurer cette sauvegarde. Vérifie qu'il s'agit bien d'un fichier généré par l'app.",
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final activeCount = _scouts
        .where((scout) => scout.statut == ScoutStatus.actif)
        .length;
    final inactiveCount = _scouts.length - activeCount;
    final scouts = _scouts.where((scout) {
      final matchesQuery = scout.displayName.toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _RosterFilter.all => true,
        _RosterFilter.active => scout.statut == ScoutStatus.actif,
        _RosterFilter.inactive => scout.statut == ScoutStatus.inactif,
      };
      return matchesQuery && matchesFilter;
    }).toList();

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _rosterHeader(activeCount, inactiveCount),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openPatrouilles,
                icon: const Icon(Icons.groups_2_outlined),
                label: Text(
                  _patrouillesById.isEmpty
                      ? 'Patrouilles'
                      : 'Patrouilles · ${_patrouillesById.length}',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _dataActionsMenu(),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Les jeunes',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.forest,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Text(
              '${scouts.length} ${scouts.length == 1 ? 'membre' : 'membres'}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.ink.withValues(alpha: 0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Rechercher un nom',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer la recherche',
                    onPressed: _searchController.clear,
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(_RosterFilter.all, 'Tous', _scouts.length),
              const SizedBox(width: 8),
              _filterChip(_RosterFilter.active, 'Actifs', activeCount),
              const SizedBox(width: 8),
              _filterChip(_RosterFilter.inactive, 'Inactifs', inactiveCount),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_loadFailed)
          _loadError()
        else if (scouts.isEmpty)
          _emptyRoster(query)
        else
          ...scouts.map(_scoutTile),
      ],
    );
  }

  Widget _loadError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 42,
            color: AppColors.ember,
          ),
          const SizedBox(height: 14),
          Text(
            'Le roster n’a pas pu être chargé.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.forest,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tes données locales ne sont pas modifiées. Réessaie dans un instant.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.ink.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              setState(() {
                _loading = true;
                _loadFailed = false;
              });
              _load();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _rosterHeader(int activeCount, int inactiveCount) {
    final troopName = _troopController.text.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
      decoration: BoxDecoration(
        gradient: AppGradients.header,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      troopName.isEmpty
                          ? 'VOTRE TROUPE'
                          : troopName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.khakiLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Une équipe,\nun même élan.',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                            letterSpacing: -0.5,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _showAddScoutDialog,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Ajouter'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.forest,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _rosterCount(Icons.verified_user_outlined, '$activeCount actifs'),
              const SizedBox(width: 18),
              _rosterCount(
                Icons.pause_circle_outline,
                '$inactiveCount inactifs',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rosterCount(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColors.khakiLight),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _dataActionsMenu() {
    return PopupMenuButton<_RosterAction>(
      tooltip: 'Gestion des données',
      onSelected: (action) {
        switch (action) {
          case _RosterAction.backup:
            _backupData();
          case _RosterAction.restore:
            _restoreData();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _RosterAction.backup,
          enabled: !_backingUp,
          child: Row(
            children: [
              const Icon(Icons.backup_outlined),
              const SizedBox(width: 12),
              Text(_backingUp ? 'Sauvegarde en cours…' : 'Sauvegarder'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _RosterAction.restore,
          enabled: !_restoring,
          child: Row(
            children: [
              const Icon(Icons.restore_outlined),
              const SizedBox(width: 12),
              Text(_restoring ? 'Restauration en cours…' : 'Restaurer'),
            ],
          ),
        ),
      ],
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.khakiLight),
        ),
        child: const Icon(Icons.more_horiz, color: AppColors.forest),
      ),
    );
  }

  Widget _filterChip(_RosterFilter filter, String label, int count) {
    final selected = _filter == filter;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      label: Text('$label  $count'),
      onSelected: (_) => setState(() => _filter = filter),
      avatar: selected ? const Icon(Icons.check, size: 16) : null,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: AppColors.forest,
      backgroundColor: Theme.of(context).colorScheme.surface,
      side: BorderSide(
        color: selected ? AppColors.forest : AppColors.khakiLight,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }

  Widget _emptyRoster(String query) {
    final hasScouts = _scouts.isNotEmpty;
    final title = hasScouts ? 'Aucun résultat' : 'Le roster commence ici';
    final message = hasScouts
        ? 'Essaie un autre nom ou change le filtre.'
        : 'Ajoute les jeunes de la troupe pour préparer les présences.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.mossLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_2_outlined,
              color: AppColors.forest,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.ink.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          if (!hasScouts)
            FilledButton.icon(
              onPressed: _showAddScoutDialog,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Ajouter un jeune'),
            )
          else
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() => _filter = _RosterFilter.all);
              },
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: Text(
                query.isEmpty ? 'Voir tous les membres' : 'Effacer les filtres',
              ),
            ),
        ],
      ),
    );
  }

  Widget _scoutTile(Scout scout) {
    final active = scout.statut == ScoutStatus.actif;
    final patrouille = scout.patrouilleId != null
        ? _patrouillesById[scout.patrouilleId]
        : null;
    final avatarImage = avatarImageFor(scout.photoPath);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _openProfile(scout),
        contentPadding: const EdgeInsets.fromLTRB(14, 5, 8, 5),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: active
              ? AppColors.mossLight
              : AppColors.parchmentDeep,
          backgroundImage: avatarImage,
          child: avatarImage == null
              ? Text(
                  scout.prenom.isNotEmpty
                      ? scout.prenom.characters.first.toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
        title: Text(
          scout.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _statusBadge(active),
              if (patrouille != null) _patrolBadge(scout, patrouille),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Actions pour ${scout.displayName}',
          onSelected: (value) {
            if (value == 'edit') {
              _editScout(scout);
            } else if (value == 'status') {
              _toggleStatus(scout);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit_outlined),
                title: Text('Modifier'),
              ),
            ),
            PopupMenuItem(
              value: 'status',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  active
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                ),
                title: Text(active ? 'Désactiver' : 'Réactiver'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(bool active) {
    final color = active
        ? AppColors.moss
        : AppColors.ink.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.mossLight : AppColors.parchmentDeep,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.circle : Icons.pause_circle,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            active ? 'Actif' : 'Inactif',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _patrolBadge(Scout scout, Patrouille patrouille) {
    final color = patrouilleColorFromHex(patrouille.couleur);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        scout.rolePatrouille == RolePatrouille.membre
            ? patrouille.nom
            : '${patrouille.nom} · ${scout.rolePatrouille.shortLabel}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
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
