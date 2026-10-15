# Stockage local 0.4.0

Les données métier quittent les trois clés `shared_preferences` au profit d’une base Sembast : fichier local sur Linux/Android/Windows, adaptateur IndexedDB pour le navigateur. Les préférences restent utilisées pour les paramètres de synchronisation et comme source de migration.

Sembast est une base embarquée en Dart avec transactions ; elle ne nécessite pas de service cloud ni de serveur installé chez l’utilisateur. Il ne s’agit pas d’une base SQL. Références : [Sembast](https://pub.dev/packages/sembast), [adaptateur Web](https://pub.dev/packages/sembast_web).

## Données et migration

Le fichier `poulpoints-v4.db` se trouve dans le dossier de support applicatif fourni par la plateforme. Sur Linux, l’identité `com.example.poulpoints` est conservée pour retrouver les préférences existantes. Sur Android, le stockage est dans le dossier privé de `org.poulapp.poulpoints`.

La première ouverture valide toutes les anciennes tâches, listes et suppressions avant de créer la première version du stockage. La transaction enregistre aussi une copie de migration. Les clés historiques `poulpoints_tasks_v1`, `poulpoints_projects_v2`, `poulpoints_deletions_v3` ne sont ni supprimées ni réécrites.

Une fois migrée, l’application utilise uniquement la nouvelle base pour les tâches. Revenir à la version 0.3.2 affichera donc les anciennes données, pas les nouvelles modifications. Pour un transfert ou un retour volontaire vers une autre version compatible, exporter le JSON actuel avant de changer de version.

Si les anciennes données ou la base ne sont pas lisibles, l’application bloque les modifications. Elle ne remet pas automatiquement les données à zéro. Ne pas supprimer les fichiers pour faire disparaître le message : conserver une copie et diagnostiquer l’erreur.

## Garanties et limites

- Une transaction enregistre l’ensemble tâches/projets/suppressions et la copie précédente.
- Les écritures déclenchées rapidement sont exécutées dans l’ordre avec des snapshots figés.
- Une révision détecte un client devenu obsolète ; le stockage fichier ajoute un verrou pendant toute la session pour éviter deux instances natives concurrentes.
- Importer une sauvegarde ne remplace l’affichage qu’après validation et écriture réussie.
- Un échec d’écriture laisse les modifications visibles avec « Réessayer la sauvegarde » et « Copier une sauvegarde ». Ne pas fermer avant de sauvegarder ou d’exporter ces modifications.
- « Restaurer la sauvegarde précédente » restaure le dernier état enregistré après confirmation. C’est un seul niveau, pas un historique. L’ancien état courant devient à son tour la version précédente.
- Cette copie est dans la même base : elle ne remplace pas une sauvegarde externe face à la perte du disque ou à la corruption complète du fichier.
- Le stockage local n’est pas chiffré. Les tâches sont chargées en mémoire ; ce format reste destiné à une application personnelle de taille raisonnable.
- Pas de synchronisation automatique ajoutée dans cette version. Les anciens clients synchronisés doivent être mis à jour pour préserver les récurrences personnalisées.

Les exports/imports gardent le format JSON `schemaVersion: 3`. La base interne utilise `storageVersion: 1` et refuse une version inconnue au lieu de l’écraser.

## Tests

Les tests unitaires utilisent de vraies transactions Sembast, dont un fichier temporaire fermé puis rouvert. Les tests graphiques isolent la couche stockage pour vérifier l’interface de création, les erreurs de sauvegarde et les nouvelles tentatives. Le test d’intégration `integration_test/storage_native_test.dart` exerce les chemins natifs et les préférences réelles ; il est réservé à un profil jetable car il écrit des données de test.
