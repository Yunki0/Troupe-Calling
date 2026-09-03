class Youth {
  final String id;
  final String name;
  final int createdAt;

  Youth({required this.id, required this.name, required this.createdAt});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'createdAt': createdAt,
      };

  factory Youth.fromMap(Map<String, dynamic> map) => Youth(
        id: map['id'] as String,
        name: map['name'] as String,
        createdAt: map['createdAt'] as int,
      );
}

class AttendanceRecord {
  final String id; // date::youthId
  final String date; // yyyy-MM-dd
  final String youthId;
  final String time; // ISO8601

  AttendanceRecord({
    required this.id,
    required this.date,
    required this.youthId,
    required this.time,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'youthId': youthId,
        'time': time,
      };

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) =>
      AttendanceRecord(
        id: map['id'] as String,
        date: map['date'] as String,
        youthId: map['youthId'] as String,
        time: map['time'] as String,
      );
}

enum ScoutStatus { actif, inactif }

/// Rôle du jeune au sein de sa patrouille.
enum RolePatrouille { membre, second, chef }

extension RolePatrouilleLabel on RolePatrouille {
  String get label {
    switch (this) {
      case RolePatrouille.chef:
        return 'Chef de patrouille';
      case RolePatrouille.second:
        return 'Second';
      case RolePatrouille.membre:
        return 'Membre';
    }
  }

  String get shortLabel {
    switch (this) {
      case RolePatrouille.chef:
        return 'CP';
      case RolePatrouille.second:
        return 'SP';
      case RolePatrouille.membre:
        return '';
    }
  }
}

class Patrouille {
  final String id;
  final String nom;
  final String? couleur; // couleur hexadécimale, ex: "#C1440E"
  final int createdAt;

  const Patrouille({
    required this.id,
    required this.nom,
    this.couleur,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'couleur': couleur,
        'created_at': createdAt,
      };

  factory Patrouille.fromMap(Map<String, dynamic> map) => Patrouille(
        id: map['id'] as String,
        nom: map['nom'] as String,
        couleur: map['couleur'] as String?,
        createdAt: map['created_at'] as int,
      );
}

class Scout {
  final String id;
  final String nom;
  final String prenom;
  final String qrToken;
  final ScoutStatus statut;
  final int createdAt;

  // --- Fiche technique (v2) ---
  final String? dateNaissance; // yyyy-MM-dd
  final String? lieuNaissance;
  final String? adresse;
  final String? parentNom;
  final String? parentContact;
  final String? photoPath; // chemin local du fichier image

  // --- Patrouille (v2) ---
  final String? patrouilleId;
  final RolePatrouille rolePatrouille;

  const Scout({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.qrToken,
    required this.statut,
    required this.createdAt,
    this.dateNaissance,
    this.lieuNaissance,
    this.adresse,
    this.parentNom,
    this.parentContact,
    this.photoPath,
    this.patrouilleId,
    this.rolePatrouille = RolePatrouille.membre,
  });

  String get displayName => '$prenom $nom'.trim();

  Scout copyWith({
    String? nom,
    String? prenom,
    ScoutStatus? statut,
    String? dateNaissance,
    String? lieuNaissance,
    String? adresse,
    String? parentNom,
    String? parentContact,
    String? photoPath,
    String? patrouilleId,
    bool clearPatrouille = false,
    RolePatrouille? rolePatrouille,
  }) {
    return Scout(
      id: id,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      qrToken: qrToken,
      statut: statut ?? this.statut,
      createdAt: createdAt,
      dateNaissance: dateNaissance ?? this.dateNaissance,
      lieuNaissance: lieuNaissance ?? this.lieuNaissance,
      adresse: adresse ?? this.adresse,
      parentNom: parentNom ?? this.parentNom,
      parentContact: parentContact ?? this.parentContact,
      photoPath: photoPath ?? this.photoPath,
      patrouilleId: clearPatrouille ? null : (patrouilleId ?? this.patrouilleId),
      rolePatrouille: rolePatrouille ?? this.rolePatrouille,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'prenom': prenom,
        'qr_token': qrToken,
        'statut': statut.name,
        'created_at': createdAt,
        'date_naissance': dateNaissance,
        'lieu_naissance': lieuNaissance,
        'adresse': adresse,
        'parent_nom': parentNom,
        'parent_contact': parentContact,
        'photo_path': photoPath,
        'patrouille_id': patrouilleId,
        'role_patrouille': rolePatrouille.name,
      };

  factory Scout.fromMap(Map<String, dynamic> map) => Scout(
        id: map['id'] as String,
        nom: map['nom'] as String,
        prenom: map['prenom'] as String,
        qrToken: map['qr_token'] as String,
        statut: ScoutStatus.values.byName(map['statut'] as String),
        createdAt: map['created_at'] as int,
        dateNaissance: map['date_naissance'] as String?,
        lieuNaissance: map['lieu_naissance'] as String?,
        adresse: map['adresse'] as String?,
        parentNom: map['parent_nom'] as String?,
        parentContact: map['parent_contact'] as String?,
        photoPath: map['photo_path'] as String?,
        patrouilleId: map['patrouille_id'] as String?,
        rolePatrouille: map['role_patrouille'] == null
            ? RolePatrouille.membre
            : RolePatrouille.values.byName(map['role_patrouille'] as String),
      );
}

enum ReunionStatus { ouverte, terminee }

class Reunion {
  final String id;
  final String date;
  final String heureDebut;
  final String? heureFin;
  final String? compteRendu;
  final String? createdBy;
  final int totalScouts;
  final ReunionStatus statut;
  final int createdAt;

  const Reunion({
    required this.id,
    required this.date,
    required this.heureDebut,
    this.heureFin,
    this.compteRendu,
    this.createdBy,
    required this.totalScouts,
    required this.statut,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'heure_debut': heureDebut,
        'heure_fin': heureFin,
        'compte_rendu': compteRendu,
        'created_by': createdBy,
        'total_scouts': totalScouts,
        'statut': statut.name,
        'created_at': createdAt,
      };

  factory Reunion.fromMap(Map<String, dynamic> map) => Reunion(
        id: map['id'] as String,
        date: map['date'] as String,
        heureDebut: map['heure_debut'] as String,
        heureFin: map['heure_fin'] as String?,
        compteRendu: map['compte_rendu'] as String?,
        createdBy: map['created_by'] as String?,
        totalScouts: map['total_scouts'] as int,
        statut: ReunionStatus.values.byName(map['statut'] as String),
        createdAt: map['created_at'] as int,
      );
}

class Presence {
  final String id;
  final String reunionId;
  final String scoutId;
  final String scannedAt;

  const Presence({
    required this.id,
    required this.reunionId,
    required this.scoutId,
    required this.scannedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'reunion_id': reunionId,
        'scout_id': scoutId,
        'scanned_at': scannedAt,
      };

  factory Presence.fromMap(Map<String, dynamic> map) => Presence(
        id: map['id'] as String,
        reunionId: map['reunion_id'] as String,
        scoutId: map['scout_id'] as String,
        scannedAt: map['scanned_at'] as String,
      );
}
