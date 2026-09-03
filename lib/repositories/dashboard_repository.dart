import '../models/models.dart';
import 'patrouille_repository.dart';
import 'presence_repository.dart';
import 'reunion_repository.dart';
import 'scout_repository.dart';

class UpcomingBirthday {
  final Scout scout;
  final DateTime nextBirthday;
  final int turningAge;
  final int daysUntil;

  const UpcomingBirthday({
    required this.scout,
    required this.nextBirthday,
    required this.turningAge,
    required this.daysUntil,
  });
}

class PatrouilleStat {
  final Patrouille patrouille;
  final int membres;
  final double tauxPresence; // 0-100, sur les réunions considérées

  const PatrouilleStat({
    required this.patrouille,
    required this.membres,
    required this.tauxPresence,
  });
}

class DashboardData {
  final int totalActifs;
  final int totalInactifs;
  final int totalPatrouilles;
  final int sansPatrouille;
  final double? tauxDerniereReunion;
  final double tauxMoyenRecent;
  final int reunionsConsiderees;
  final List<PatrouilleStat> statsPatrouilles;
  final List<UpcomingBirthday> anniversaires;
  final List<Scout> meilleureAssiduite;

  const DashboardData({
    required this.totalActifs,
    required this.totalInactifs,
    required this.totalPatrouilles,
    required this.sansPatrouille,
    required this.tauxDerniereReunion,
    required this.tauxMoyenRecent,
    required this.reunionsConsiderees,
    required this.statsPatrouilles,
    required this.anniversaires,
    required this.meilleureAssiduite,
  });

  static const empty = DashboardData(
    totalActifs: 0,
    totalInactifs: 0,
    totalPatrouilles: 0,
    sansPatrouille: 0,
    tauxDerniereReunion: null,
    tauxMoyenRecent: 0,
    reunionsConsiderees: 0,
    statsPatrouilles: [],
    anniversaires: [],
    meilleureAssiduite: [],
  );
}

class DashboardRepository {
  final ScoutRepository _scoutRepo;
  final PatrouilleRepository _patrouilleRepo;
  final ReunionRepository _reunionRepo;
  final PresenceRepository _presenceRepo;

  DashboardRepository({
    ScoutRepository? scoutRepository,
    PatrouilleRepository? patrouilleRepository,
    ReunionRepository? reunionRepository,
    PresenceRepository? presenceRepository,
  })  : _scoutRepo = scoutRepository ?? ScoutRepository(),
        _patrouilleRepo = patrouilleRepository ?? PatrouilleRepository(),
        _reunionRepo = reunionRepository ?? ReunionRepository(),
        _presenceRepo = presenceRepository ?? PresenceRepository();

  Future<DashboardData> load({
    int recentReunionsCount = 6,
    int birthdayWindowDays = 30,
  }) async {
    final scouts = await _scoutRepo.getAll();
    final patrouilles = await _patrouilleRepo.getAll();
    final allReunions = await _reunionRepo.getAll(); // triées date DESC
    final terminees = allReunions.where((r) => r.statut == ReunionStatus.terminee).toList();
    final recent = terminees.take(recentReunionsCount).toList();

    final actifs = scouts.where((s) => s.statut == ScoutStatus.actif).toList();
    final inactifs = scouts.where((s) => s.statut == ScoutStatus.inactif).toList();
    final sansPatrouille = actifs.where((s) => s.patrouilleId == null).length;

    final presencesByReunion = <String, List<Presence>>{};
    for (final r in recent) {
      presencesByReunion[r.id] = await _presenceRepo.getForReunion(r.id);
    }

    double? tauxDerniere;
    if (recent.isNotEmpty) {
      final r = recent.first;
      final total = r.totalScouts > 0 ? r.totalScouts : actifs.length;
      final present = presencesByReunion[r.id]?.length ?? 0;
      tauxDerniere = total == 0 ? 0 : present * 100 / total;
    }

    double tauxMoyen = 0;
    if (recent.isNotEmpty) {
      final rates = recent.map((r) {
        final total = r.totalScouts > 0 ? r.totalScouts : actifs.length;
        final present = presencesByReunion[r.id]?.length ?? 0;
        return total == 0 ? 0.0 : present * 100 / total;
      }).toList();
      tauxMoyen = rates.reduce((a, b) => a + b) / rates.length;
    }

    final statsPatrouilles = <PatrouilleStat>[];
    for (final p in patrouilles) {
      final membres = actifs.where((s) => s.patrouilleId == p.id).toList();
      if (membres.isEmpty || recent.isEmpty) {
        statsPatrouilles.add(PatrouilleStat(patrouille: p, membres: membres.length, tauxPresence: 0));
        continue;
      }
      final memberIds = membres.map((s) => s.id).toSet();
      var presentCount = 0;
      for (final r in recent) {
        final presences = presencesByReunion[r.id] ?? const [];
        presentCount += presences.where((pr) => memberIds.contains(pr.scoutId)).length;
      }
      final possible = membres.length * recent.length;
      final taux = possible == 0 ? 0.0 : presentCount * 100 / possible;
      statsPatrouilles.add(PatrouilleStat(patrouille: p, membres: membres.length, tauxPresence: taux));
    }
    statsPatrouilles.sort((a, b) => b.tauxPresence.compareTo(a.tauxPresence));

    final presenceCountByScout = <String, int>{};
    for (final r in recent) {
      for (final pr in presencesByReunion[r.id] ?? const []) {
        presenceCountByScout[pr.scoutId] = (presenceCountByScout[pr.scoutId] ?? 0) + 1;
      }
    }
    final ranked = List<Scout>.from(actifs)
      ..sort((a, b) => (presenceCountByScout[b.id] ?? 0).compareTo(presenceCountByScout[a.id] ?? 0));
    final meilleureAssiduite = recent.isEmpty ? <Scout>[] : ranked.take(5).toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = <UpcomingBirthday>[];
    for (final s in actifs) {
      if (s.dateNaissance == null) continue;
      final birth = DateTime.tryParse(s.dateNaissance!);
      if (birth == null) continue;
      var next = DateTime(today.year, birth.month, birth.day);
      if (next.isBefore(today)) {
        next = DateTime(today.year + 1, birth.month, birth.day);
      }
      final daysUntil = next.difference(today).inDays;
      if (daysUntil <= birthdayWindowDays) {
        upcoming.add(UpcomingBirthday(
          scout: s,
          nextBirthday: next,
          turningAge: next.year - birth.year,
          daysUntil: daysUntil,
        ));
      }
    }
    upcoming.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));

    return DashboardData(
      totalActifs: actifs.length,
      totalInactifs: inactifs.length,
      totalPatrouilles: patrouilles.length,
      sansPatrouille: sansPatrouille,
      tauxDerniereReunion: tauxDerniere,
      tauxMoyenRecent: tauxMoyen,
      reunionsConsiderees: recent.length,
      statsPatrouilles: statsPatrouilles,
      anniversaires: upcoming,
      meilleureAssiduite: meilleureAssiduite,
    );
  }
}
