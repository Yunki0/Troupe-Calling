import 'package:flutter_test/flutter_test.dart';
import 'package:troupe_manager/models/models.dart';

void main() {
  test('Scout preserves its opaque QR token when converted to SQLite', () {
    const scout = Scout(
      id: 'scout-id-1',
      nom: 'Dupont',
      prenom: 'Jean',
      qrToken: 'scout_opaque_123',
      statut: ScoutStatus.actif,
      createdAt: 1000,
    );

    final restored = Scout.fromMap(scout.toMap());

    expect(restored.id, scout.id);
    expect(restored.displayName, 'Jean Dupont');
    expect(restored.qrToken, scout.qrToken);
    expect(restored.statut, ScoutStatus.actif);
  });

  test('Reunion preserves nullable fields and status', () {
    const reunion = Reunion(
      id: 'reunion-1',
      date: '2026-09-05',
      heureDebut: '15:00',
      heureFin: null,
      compteRendu: 'Formation aux nœuds',
      createdBy: 'Chef 1',
      totalScouts: 12,
      statut: ReunionStatus.ouverte,
      createdAt: 1000,
    );

    final restored = Reunion.fromMap(reunion.toMap());

    expect(restored.id, reunion.id);
    expect(restored.heureFin, isNull);
    expect(restored.compteRendu, reunion.compteRendu);
    expect(restored.totalScouts, 12);
    expect(restored.statut, ReunionStatus.ouverte);
  });

  test('Presence keeps the reunion and scout relationship', () {
    const presence = Presence(
      id: 'reunion-1::scout-1',
      reunionId: 'reunion-1',
      scoutId: 'scout-1',
      scannedAt: '2026-09-05T15:12:00.000',
    );

    final restored = Presence.fromMap(presence.toMap());

    expect(restored.id, 'reunion-1::scout-1');
    expect(restored.reunionId, 'reunion-1');
    expect(restored.scoutId, 'scout-1');
    expect(restored.scannedAt, '2026-09-05T15:12:00.000');
  });
}
