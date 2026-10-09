# Préparation à la synchronisation

L’application reste **hors ligne par défaut**. Aucune synchronisation ni
transmission de données n’est activée par cette préparation.

## Versionnement

- `DatabaseHelper.schemaVersion` et `PRAGMA user_version` versionnent le
  schéma SQLite local. Une évolution de schéma doit passer par une migration
  additive, testée depuis les versions locales encore prises en charge.
- Le protocole réseau devra posséder sa propre version : une version de
  protocole ne doit pas être déduite du numéro de migration SQLite.
- Les identifiants locaux existants sont opaques et stables. Le serveur devra
  les conserver, et les opérations envoyées devront être idempotentes.

## Politique de convergence proposée

- Garder les écritures locales disponibles hors connexion et les transmettre
  depuis une file persistante d’opérations, créée dans la même transaction que
  la modification locale. Une suppression doit produire un tombstone, pas
  disparaître immédiatement de l’historique de synchronisation.
- Utiliser une révision monotone par enregistrement et un curseur distant
  opaque. Une reprise après interruption renvoie les opérations non acquittées;
  leur clé d’idempotence évite les doublons.
- Ne pas appliquer de « dernier horodatage gagnant » en silence aux fiches,
  aux affectations de patrouille ou aux rôles chef/second. Une modification
  concurrente doit être retournée comme conflit explicite, puis résolue par un
  utilisateur autorisé.
- Les présences sont uniques par réunion et scout. Une présence ajoutée sur
  deux appareils converge vers une seule entrée; une correction ou suppression
  explicite reste une opération révisable et ne doit pas être confondue avec
  l’absence d’une entrée sur un appareil.
- La clôture d’une réunion est une transition terminale. Le compte-rendu doit
  être versionné séparément afin qu’une édition concurrente ne remplace pas
  silencieusement le texte d’un autre appareil.
- Les photos doivent être transférées comme objets séparés, vérifiés par
  empreinte, puis référencés par un identifiant logique plutôt que par un
  chemin de fichier propre à un appareil.

Avant une première synchronisation réelle, il reste à définir le modèle
d’authentification et de rôles d’accès, le consentement et la rétention des
données personnelles (notamment celles des parents), ainsi que le serveur et
la stratégie de chiffrement. L’implémentation devra ajouter la file de
synchronisation, les révisions et les tombstones dans une migration dédiée et
tester les conflits hors ligne multi-appareils.
