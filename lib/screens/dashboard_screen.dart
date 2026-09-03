import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/dashboard_repository.dart';
import '../theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = DashboardRepository();
  DashboardData _data = DashboardData.empty;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _repo.load();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  Color _colorOf(String? hex) {
    if (hex == null) return AppColors.khaki;
    return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bienvenue Chef')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _overviewGrid(),
                  const SizedBox(height: 18),
                  _sectionTitle('🎂 Anniversaires à venir'),
                  const SizedBox(height: 8),
                  _birthdaysSection(),
                  const SizedBox(height: 20),
                  _sectionTitle('📊 Présence récente'),
                  const SizedBox(height: 8),
                  _attendanceOverview(),
                  const SizedBox(height: 20),
                  if (_data.statsPatrouilles.isNotEmpty) ...[
                    _sectionTitle('🏕 Par patrouille'),
                    const SizedBox(height: 8),
                    _patrouilleStats(),
                    const SizedBox(height: 20),
                  ],
                  if (_data.meilleureAssiduite.isNotEmpty) ...[
                    _sectionTitle('⭐ Assiduité (top 5)'),
                    const SizedBox(height: 8),
                    _topAssiduite(),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.forest),
      );

  Widget _overviewGrid() {
    final items = [
      (_data.totalActifs.toString(), 'Actifs'),
      (_data.totalInactifs.toString(), 'Inactifs'),
      (_data.totalPatrouilles.toString(), 'Patrouilles'),
      (_data.sansPatrouille.toString(), 'Sans patrouille'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: items
          .map((item) => Container(
                decoration: BoxDecoration(
                  gradient: AppGradients.header,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.card,
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.$1,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                    Text(item.$2, style: const TextStyle(color: AppColors.khakiLight, fontSize: 12)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _birthdaysSection() {
    if (_data.anniversaires.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Aucun anniversaire dans les 30 prochains jours.', style: TextStyle(color: Colors.black54)),
        ),
      );
    }
    return Card(
      child: Column(
        children: _data.anniversaires.map((b) {
          final isToday = b.daysUntil == 0;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isToday ? AppColors.ember.withValues(alpha: 0.15) : AppColors.mossLight,
              backgroundImage: b.scout.photoPath != null ? FileImage(File(b.scout.photoPath!)) : null,
              child: b.scout.photoPath == null
                  ? Text(b.scout.prenom.isNotEmpty ? b.scout.prenom[0] : '?')
                  : null,
            ),
            title: Text(b.scout.displayName),
            subtitle: Text(
              isToday
                  ? "Aujourd'hui — fête ses ${b.turningAge} ans 🎉"
                  : '${DateFormat('d MMMM', 'fr_FR').format(b.nextBirthday)} — fêtera ses ${b.turningAge} ans',
            ),
            trailing: isToday
                ? const Icon(Icons.cake, color: AppColors.ember)
                : Text('J-${b.daysUntil}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
          );
        }).toList(),
      ),
    );
  }

  Widget _attendanceOverview() {
    if (_data.reunionsConsiderees == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Pas encore de réunion terminée pour calculer des statistiques.',
              style: TextStyle(color: Colors.black54)),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _statTile(
            _data.tauxDerniereReunion == null ? '—' : '${_data.tauxDerniereReunion!.toStringAsFixed(0)}%',
            'Dernière séance',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(
            '${_data.tauxMoyenRecent.toStringAsFixed(0)}%',
            'Moyenne (${_data.reunionsConsiderees} dern.)',
          ),
        ),
      ],
    );
  }

  Widget _statTile(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.khakiLight),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.forest)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.black54), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _patrouilleStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        child: Column(
          children: _data.statsPatrouilles.map((s) {
            final color = _colorOf(s.patrouille.couleur);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(radius: 5, backgroundColor: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${s.patrouille.nom} · ${s.membres} membre(s)',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Text('${s.tauxPresence.toStringAsFixed(0)}%',
                          style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 8,
                      child: Stack(
                        children: [
                          Container(color: AppColors.khakiLight.withValues(alpha: 0.5)),
                          FractionallySizedBox(
                            widthFactor: (s.tauxPresence / 100).clamp(0.0, 1.0),
                            child: Container(color: color),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _topAssiduite() {
    return Card(
      child: Column(
        children: _data.meilleureAssiduite.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final scout = entry.value;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: rank == 1 ? AppColors.gold.withValues(alpha: 0.25) : AppColors.mossLight,
              child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.forest)),
            ),
            title: Text(scout.displayName),
          );
        }).toList(),
      ),
    );
  }
}
