import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../repositories/patrouille_repository.dart';
import '../repositories/scout_repository.dart';
import '../theme.dart';

class ScoutProfileScreen extends StatefulWidget {
  final Scout scout;
  const ScoutProfileScreen({super.key, required this.scout});

  @override
  State<ScoutProfileScreen> createState() => _ScoutProfileScreenState();
}

class _ScoutProfileScreenState extends State<ScoutProfileScreen> with SingleTickerProviderStateMixin {
  final _scoutRepo = ScoutRepository();
  final _patrouilleRepo = PatrouilleRepository();
  final _picker = ImagePicker();
  final _repaintKey = GlobalKey();

  late TabController _tabController;
  late Scout _scout;
  List<Patrouille> _patrouilles = [];

  final _prenomCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _lieuNaissanceCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _parentNomCtrl = TextEditingController();
  final _parentContactCtrl = TextEditingController();
  DateTime? _dateNaissance;

  String? _selectedPatrouilleId;
  RolePatrouille _selectedRole = RolePatrouille.membre;

  bool _saving = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scout = widget.scout;
    _syncControllersFromScout();
    _loadPatrouilles();
  }

  /// Recopie les champs de [_scout] vers les controllers / sélections
  /// d'écran. Centralisé ici pour être ré-appelable après un rechargement
  /// depuis la base, et pas seulement à l'ouverture de l'écran.
  void _syncControllersFromScout() {
    _prenomCtrl.text = _scout.prenom;
    _nomCtrl.text = _scout.nom;
    _lieuNaissanceCtrl.text = _scout.lieuNaissance ?? '';
    _adresseCtrl.text = _scout.adresse ?? '';
    _parentNomCtrl.text = _scout.parentNom ?? '';
    _parentContactCtrl.text = _scout.parentContact ?? '';
    _dateNaissance = _scout.dateNaissance != null ? DateTime.tryParse(_scout.dateNaissance!) : null;
    _selectedPatrouilleId = _scout.patrouilleId;
    _selectedRole = _scout.rolePatrouille;
  }

  Future<void> _loadPatrouilles() async {
    final list = await _patrouilleRepo.getAll();
    if (mounted) setState(() => _patrouilles = list);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _lieuNaissanceCtrl.dispose();
    _adresseCtrl.dispose();
    _parentNomCtrl.dispose();
    _parentContactCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 900);
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${dir.path}/photos');
      if (!await photosDir.exists()) await photosDir.create(recursive: true);
      final destPath = '${photosDir.path}/${_scout.id}.jpg';
      await File(picked.path).copy(destPath);
      await _scoutRepo.updatePhoto(_scout.id, destPath);
      if (!mounted) return;
      setState(() => _scout = _scout.copyWith(photoPath: destPath));
    } catch (_) {
      _message("Impossible de mettre à jour la photo. Vérifie les autorisations caméra/galerie de l'app.");
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera, color: AppColors.forest),
            title: const Text('Prendre une photo'),
            onTap: () {
              Navigator.pop(ctx);
              _pickPhoto(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: AppColors.forest),
            title: const Text('Choisir dans la galerie'),
            onTap: () {
              Navigator.pop(ctx);
              _pickPhoto(ImageSource.gallery);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _pickDateNaissance() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateNaissance ?? DateTime(2012, 1, 1),
      firstDate: DateTime(1995),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateNaissance = picked);
  }

  /// Quand on retire la patrouille, le rôle n'a plus de sens : on le
  /// remet à "membre" immédiatement dans l'UI (la base le fait déjà de son
  /// côté, mais l'écran doit refléter la même règle avant même d'enregistrer).
  void _onPatrouilleChanged(String? patrouilleId) {
    setState(() {
      _selectedPatrouilleId = patrouilleId;
      if (patrouilleId == null) {
        _selectedRole = RolePatrouille.membre;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    String? patrouilleError;
    try {
      await _scoutRepo.updateProfile(
        id: _scout.id,
        prenom: _prenomCtrl.text.trim(),
        nom: _nomCtrl.text.trim(),
      );
      await _scoutRepo.updateFicheTechnique(
        id: _scout.id,
        dateNaissance: _dateNaissance != null ? DateFormat('yyyy-MM-dd').format(_dateNaissance!) : null,
        lieuNaissance: _lieuNaissanceCtrl.text.trim().isEmpty ? null : _lieuNaissanceCtrl.text.trim(),
        adresse: _adresseCtrl.text.trim().isEmpty ? null : _adresseCtrl.text.trim(),
        parentNom: _parentNomCtrl.text.trim().isEmpty ? null : _parentNomCtrl.text.trim(),
        parentContact: _parentContactCtrl.text.trim().isEmpty ? null : _parentContactCtrl.text.trim(),
      );

      try {
        await _scoutRepo.assignPatrouille(
          scoutId: _scout.id,
          patrouilleId: _selectedPatrouilleId,
          role: _selectedRole,
        );
      } on StateError catch (e) {
        patrouilleError = e.message;
      }

      // Recharge systématiquement depuis la base, que l'affectation de
      // patrouille ait réussi ou non : l'écran doit toujours refléter l'état
      // réel de SQLite, jamais une sélection locale non confirmée.
      final reloaded = await _scoutRepo.findById(_scout.id);
      if (reloaded != null && mounted) {
        setState(() {
          _scout = reloaded;
          _syncControllersFromScout();
        });
      }

      if (mounted) {
        _message(patrouilleError == null
            ? 'Fiche enregistrée.'
            : 'Fiche enregistrée. Patrouille non modifiée : $patrouilleError');
      }
    } catch (_) {
      _message("Impossible d'enregistrer la fiche. Réessaie.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareBadge() async {
    setState(() => _sharing = true);
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/badge_${_scout.id}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Badge scout — ${_scout.displayName}',
      );
    } catch (_) {
      _message('Impossible de préparer le badge à partager. Réessaie.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _message(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_scout.displayName),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.ember,
          tabs: const [Tab(text: 'Fiche technique'), Tab(text: 'Badge QR')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_ficheTab(), _badgeTab()],
      ),
    );
  }

  Widget _ficheTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: GestureDetector(
            onTap: _showPhotoSourceSheet,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.mossLight,
                  backgroundImage: _scout.photoPath != null ? FileImage(File(_scout.photoPath!)) : null,
                  child: _scout.photoPath == null
                      ? Text(_scout.prenom.isNotEmpty ? _scout.prenom[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 32, color: AppColors.forest))
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: AppColors.ember, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: TextField(controller: _prenomCtrl, decoration: const InputDecoration(labelText: 'Prénom'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _nomCtrl, decoration: const InputDecoration(labelText: 'Nom'))),
        ]),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickDateNaissance,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Date de naissance'),
            child: Text(_dateNaissance != null ? DateFormat('dd/MM/yyyy').format(_dateNaissance!) : 'Non renseignée'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(controller: _lieuNaissanceCtrl, decoration: const InputDecoration(labelText: 'Lieu de naissance')),
        const SizedBox(height: 12),
        TextField(controller: _adresseCtrl, decoration: const InputDecoration(labelText: "Lieu d'habitation"), maxLines: 2),
        const SizedBox(height: 20),
        const Text('Contact parent', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.forest)),
        const SizedBox(height: 8),
        TextField(controller: _parentNomCtrl, decoration: const InputDecoration(labelText: 'Nom du parent')),
        const SizedBox(height: 12),
        TextField(
          controller: _parentContactCtrl,
          decoration: const InputDecoration(labelText: 'Téléphone / contact'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 20),
        const Text('Patrouille', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.forest)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: _selectedPatrouilleId,
          decoration: const InputDecoration(labelText: 'Patrouille'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Aucune')),
            ..._patrouilles.map((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.nom))),
          ],
          onChanged: _onPatrouilleChanged,
        ),
        const SizedBox(height: 12),
        if (_selectedPatrouilleId != null)
          DropdownButtonFormField<RolePatrouille>(
            initialValue: _selectedRole,
            decoration: const InputDecoration(labelText: 'Rôle'),
            items: RolePatrouille.values
                .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                .toList(),
            onChanged: (v) => setState(() => _selectedRole = v ?? RolePatrouille.membre),
          ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
          ),
        ),
      ],
    );
  }

  Patrouille? get _currentPatrouille {
    if (_scout.patrouilleId == null) return null;
    for (final p in _patrouilles) {
      if (p.id == _scout.patrouilleId) return p;
    }
    return null;
  }

  Color _patrouilleColor(Patrouille? p) {
    if (p?.couleur == null) return AppColors.khaki;
    return Color(int.parse(p!.couleur!.substring(1), radix: 16) + 0xFF000000);
  }

  Widget _badgeTab() {
    final patrouille = _currentPatrouille;
    final accentColor = _patrouilleColor(patrouille);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          RepaintBoundary(
            key: _repaintKey,
            child: Container(
              width: 300,
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
              decoration: BoxDecoration(
                gradient: AppGradients.header,
                borderRadius: BorderRadius.circular(26),
                boxShadow: AppShadows.soft,
                border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.4),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emoji_nature, color: AppColors.khakiLight, size: 15),
                      const SizedBox(width: 6),
                      const Text(
                        'CARTE SCOUT',
                        style: TextStyle(
                          color: AppColors.khakiLight,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      if (patrouille != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: accentColor.withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            patrouille.nom,
                            style: TextStyle(color: accentColor == AppColors.khaki ? AppColors.khakiLight : Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.forestDark,
                    child: CircleAvatar(
                      radius: 33,
                      backgroundColor: AppColors.mossLight,
                      backgroundImage: _scout.photoPath != null ? FileImage(File(_scout.photoPath!)) : null,
                      child: _scout.photoPath == null
                          ? Text(_scout.prenom.isNotEmpty ? _scout.prenom[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 26, color: AppColors.forest, fontWeight: FontWeight.bold))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _scout.displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_scout.rolePatrouille != RolePatrouille.membre) ...[
                    const SizedBox(height: 2),
                    Text(_scout.rolePatrouille.label,
                        style: const TextStyle(color: AppColors.khakiLight, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppShadows.card,
                    ),
                    child: QrImageView(
                      data: _scout.qrToken,
                      size: 168,
                      gapless: true,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.forest),
                      dataModuleStyle:
                          const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _scout.qrToken,
                    style: const TextStyle(color: AppColors.khakiLight, fontSize: 9.5, letterSpacing: 0.5, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Ce badge s'affiche à l'écran ou se plastifie une fois imprimé.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _sharing ? null : _shareBadge,
            icon: _sharing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.share),
            label: Text(_sharing ? 'Préparation...' : 'Partager / imprimer'),
          ),
        ],
      ),
    );
  }
}
