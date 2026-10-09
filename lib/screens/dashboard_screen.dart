import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/dashboard_repository.dart';
import '../theme.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const DashboardScreen({super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = DashboardRepository();
  DashboardData _data = DashboardData.empty;
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _repo.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _loadFailed = false;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      debugPrint('Dashboard load failed: $error\n$stackTrace');
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _navigate(int destination) => widget.onNavigate?.call(destination);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadFailed) return _failureState();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _welcomeCard(),
          const SizedBox(height: 18),
          _sectionTitle('En un coup d’œil'),
          const SizedBox(height: 10),
          _overviewCards(),
          const SizedBox(height: 22),
          _sectionTitle('À ne pas oublier'),
          const SizedBox(height: 10),
          _birthdaysSection(),
          const SizedBox(height: 22),
          _sectionTitle('Présence récente'),
          const SizedBox(height: 10),
          _attendanceOverview(),
          if (_data.statsPatrouilles.isNotEmpty) ...[
            const SizedBox(height: 22),
            _sectionTitle('La vie des patrouilles'),
            const SizedBox(height: 10),
            _patrouilleStats(),
          ],
        ],
      ),
    );
  }

  Widget _failureState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppPalette.of(context).surfaceRaised,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sync_problem_outlined,
                size: 34,
                color: AppPalette.of(context).primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Le tableau de bord est indisponible.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppPalette.of(context).primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tes données restent sur cet appareil. Réessaie le chargement.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppPalette.of(context).textMuted,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomeCard() {
    final now = DateTime.now();
    final greeting = switch (now.hour) {
      < 12 => 'Bonjour, chef',
      < 18 => 'Bel après-midi, chef',
      _ => 'Bonsoir, chef',
    };
    final date = DateFormat('EEEE d MMMM', 'fr_FR').format(now);
    final title = _data.reunionOuverte == null
        ? 'Prêt à lancer la prochaine réunion ?'
        : 'La réunion est en cours';
    final action = _data.reunionOuverte == null
        ? 'Préparer une réunion'
        : 'Reprendre l’appel';
    final destination = _data.reunionOuverte == null ? 3 : 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: AppGradients.headerFor(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.wb_sunny_outlined,
                size: 17,
                color: AppPalette.of(context).onBrand,
              ),
              const SizedBox(width: 7),
              Text(
                '$greeting · ${_capitalize(date)}',
                style: TextStyle(
                  color: AppPalette.of(context).onBrand,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              height: 1.13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _data.reunionOuverte == null
                ? 'Ouvre une réunion dans l’historique, puis retrouve l’appel ici.'
                : 'Scanne les badges et suis les présences en direct.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _navigate(destination),
              icon: Icon(
                _data.reunionOuverte == null
                    ? Icons.event_available_outlined
                    : Icons.qr_code_scanner,
              ),
              label: Text(action),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.of(context).secondarySoft,
                foregroundColor: AppPalette.of(context).onSecondarySoft,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppPalette.of(context).primary,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _overviewCards() {
    return Row(
      children: [
        Expanded(
          child: _overviewCard(
            icon: Icons.groups_2_outlined,
            label: 'Jeunes actifs',
            value: _data.totalActifs.toString(),
            detail: _data.totalInactifs == 0
                ? 'Effectif de la troupe'
                : '${_data.totalInactifs} inactif${_data.totalInactifs == 1 ? '' : 's'}',
            onTap: () => _navigate(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _overviewCard(
            icon: Icons.flag_outlined,
            label: 'Patrouilles',
            value: _data.totalPatrouilles.toString(),
            detail: _data.sansPatrouille == 0
                ? 'Tous rattachés'
                : '${_data.sansPatrouille} sans patrouille',
            attention: _data.sansPatrouille > 0,
            onTap: () => _navigate(2),
          ),
        ),
      ],
    );
  }

  Widget _overviewCard({
    required IconData icon,
    required String label,
    required String value,
    required String detail,
    required VoidCallback onTap,
    bool attention = false,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppPalette.of(context).primary, size: 21),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppPalette.of(context).primary,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: attention
                      ? AppPalette.of(context).accent
                      : AppPalette.of(context).textMuted,
                  fontWeight: attention ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _birthdaysSection() {
    if (_data.anniversaires.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.cake_outlined,
                color: AppPalette.of(context).secondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pas d’anniversaire prévu dans les 30 prochains jours.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppPalette.of(context).textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final birthdays = _data.anniversaires.take(3).toList();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < birthdays.length; index++) ...[
            if (index > 0) const Divider(height: 1, indent: 68),
            _birthdayTile(birthdays[index]),
          ],
          if (_data.anniversaires.length > birthdays.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '+ ${_data.anniversaires.length - birthdays.length} autre${_data.anniversaires.length - birthdays.length == 1 ? '' : 's'} anniversaire${_data.anniversaires.length - birthdays.length == 1 ? '' : 's'} à venir',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppPalette.of(context).textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _birthdayTile(UpcomingBirthday birthday) {
    final isToday = birthday.daysUntil == 0;
    final avatarImage = avatarImageFor(birthday.scout.photoPath);
    final date = DateFormat('d MMMM', 'fr_FR').format(birthday.nextBirthday);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: isToday
            ? AppPalette.of(context).accentSoft
            : AppPalette.of(context).successSoft,
        backgroundImage: avatarImage,
        child: avatarImage == null
            ? Text(
                birthday.scout.prenom.isNotEmpty
                    ? birthday.scout.prenom.characters.first.toUpperCase()
                    : '?',
                style: TextStyle(
                  color: AppPalette.of(context).primary,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
      title: Text(
        birthday.scout.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(isToday ? 'Aujourd’hui 🎉' : date),
      trailing: isToday
          ? Icon(Icons.cake_outlined, color: AppPalette.of(context).accent)
          : Text(
              birthday.daysUntil == 1 ? 'Demain' : 'J-${birthday.daysUntil}',
              style: TextStyle(
                color: AppPalette.of(context).primary,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }

  Widget _attendanceOverview() {
    if (_data.reunionsConsiderees == 0) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                color: AppPalette.of(context).primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Les tendances de présence apparaîtront après une première réunion terminée.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppPalette.of(context).textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _attendanceMetric(
                    _data.tauxDerniereReunion,
                    'Dernière réunion',
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: AppPalette.of(context).outline,
                ),
                Expanded(
                  child: _attendanceMetric(
                    _data.tauxMoyenRecent,
                    'Moyenne récente',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_data.tauxDerniereReunion ?? 0) / 100,
                minHeight: 8,
                backgroundColor: AppPalette.of(context).successSoft,
                color: AppPalette.of(context).success,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Calculée sur ${_data.reunionsConsiderees} réunion${_data.reunionsConsiderees == 1 ? '' : 's'} terminée${_data.reunionsConsiderees == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.of(context).textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attendanceMetric(double? value, String label) {
    return Column(
      children: [
        Text(
          value == null ? '—' : '${value.toStringAsFixed(0)}%',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppPalette.of(context).primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppPalette.of(context).textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _patrouilleStats() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        child: Column(
          children: _data.statsPatrouilles.map((stat) {
            final color = patrouilleColorFromHex(stat.patrouille.couleur);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(radius: 5, backgroundColor: color),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '${stat.patrouille.nom} · ${stat.membres} ${stat.membres == 1 ? 'jeune' : 'jeunes'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${stat.tauxPresence.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (stat.tauxPresence / 100).clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: AppPalette.of(context).secondarySoft,
                      color: color,
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
}
