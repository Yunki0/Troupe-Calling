<div align="center">
  <img src="assets/splash_logo.png" alt="Emblème Appel Scout" width="112" />
  <h1>Appel Scout</h1>
  <p><strong>Le quotidien de la troupe, simplement.</strong></p>
  <p>
    Une application Flutter hors ligne pour suivre les jeunes,
    organiser les réunions et faire l’appel par QR code.
  </p>
</div>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-Material%203-356B45?logo=flutter&logoColor=white" alt="Flutter et Material 3" />
  <img src="https://img.shields.io/badge/Données-locales%20et%20hors%20ligne-427F59" alt="Données locales et hors ligne" />
  <img src="https://img.shields.io/badge/Langue-français-B94F36" alt="Interface en français" />
</p>

---

## À propos

**Appel Scout** accompagne les responsables dans les tâches courantes de la
troupe. L’application fonctionne localement sur l’appareil : les fonctions
principales ne nécessitent ni compte ni connexion Internet.

## Fonctionnalités

- **Accueil de suivi** : effectif, réunion en cours, anniversaires et tendances
  récentes de présence.
- **Gestion des jeunes** : roster, statut, patrouille, rôle et fiche individuelle.
- **Badges QR** : génération et partage du badge de chaque jeune.
- **Appel rapide** : scan des QR codes pendant une réunion, avec suivi des
  présences déjà enregistrées.
- **Réunions** : ouverture, clôture, historique et consultation du détail des
  présences ; export CSV.
- **Patrouilles** : gestion des patrouilles, de leur couleur et des rôles.
- **Sauvegarde locale** : export et restauration des données, avec validation
  de l’archive avant remplacement.
- **Interface française** : thème Material 3 avec une palette feuillage claire.

## Démarrer

### Prérequis

- Flutter et Dart compatibles avec les versions indiquées dans
  [`pubspec.yaml`](pubspec.yaml)
- Android SDK installé ; le module Android compile avec `compileSdk 37`

### Installation et lancement

```bash
flutter pub get
flutter run
```

Pour construire l’APK Android de développement :

```bash
flutter build apk --debug
```

Le fichier généré se trouve dans
`build/app/outputs/flutter-apk/app-debug.apk`.

Pour construire un APK release signé :

```bash
flutter build apk --release
```

La signature release utilise le keystore local référencé dans
`android/key.properties` (ignoré par Git). Le keystore doit rester dans
`android/app/` et le champ `storeFile` doit contenir son nom de fichier.
Ne partage ni ce fichier ni les mots de passe associés. Conserve une copie
sûre du keystore et de ses mots de passe : les futures mises à jour doivent
être signées avec cette même clé.

L’APK release est généré dans
`build/app/outputs/flutter-apk/app-release.apk`.
La page de téléchargement du projet propose automatiquement l’APK joint à la
dernière release GitHub publiée.

## Vérifications

Les tests couvrent les modèles, les migrations SQLite, la sauvegarde et la
restauration, le calcul des données du tableau de bord et les contrastes de la
palette.

```bash
flutter analyze
flutter test
```

## Données et confidentialité

- Les données de la troupe sont stockées dans une base SQLite sur l’appareil.
- Aucune synchronisation cloud ni transmission automatique n’est activée.
- Les exports sont lancés explicitement par le responsable via les fonctions de
  partage de l’appareil.
- Une restauration remplace les données locales actuelles. Vérifie le fichier
  choisi et conserve une copie de sauvegarde avant de confirmer.

Les principes à respecter avant toute synchronisation multi-appareils sont
documentés dans [`docs/synchronisation.md`](docs/synchronisation.md). Ce document
ne signifie pas que la synchronisation est actuellement disponible.

## Organisation du projet

```text
lib/
├── db/             # Base SQLite, schéma et migrations
├── models/         # Modèles métier
├── repositories/   # Accès aux données
├── screens/        # Écrans Flutter
├── services/       # Sauvegarde et services applicatifs
└── theme.dart      # Palette et thème partagés
test/               # Tests unitaires et de régression
```

## Pistes d’évolution

- Continuer les tests d’interface sur les parcours d’appel et de restauration.
- Définir l’identifiant Android définitif avant toute publication sur Google Play.
- Concevoir une synchronisation uniquement après définition des rôles, du
  consentement, de la rétention et de la protection des données des jeunes.
