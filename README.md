# Poulpoints 🐙

Gestionnaire de tâches libre de la gamme Poulapp, développé en Flutter.

## Plateformes

Android et Linux/Bazzite KDE sont testés. Windows, Web et notifications Web restent en attente. Le cloud est facultatif ; les tâches restent utilisables hors ligne. Le serveur Poulapp actuel est privé et sur invitation : la publication du code n’ouvre pas automatiquement les inscriptions.

## Fonctionnalités

Tâches et sous-tâches, projets, priorités, échéances datées et horaires, lieux, notes, étiquettes, recherche, récurrences personnalisées, rappels multiples et report. Widgets Android et KDE avec validation sans ouvrir la fenêtre et synchronisation en arrière-plan. Résolution manuelle des conflits cloud. Calendrier français, lundi ou dimanche au choix ; thèmes clair et sombre.

La suppression d’un projet transfère ses tâches. Les exceptions de récurrence concernent l’occurrence courante. La résolution d’un conflit choisit une version complète de la tâche.

## Version 0.8.0

Pièces jointes cloud privées, suppression automatique après complétion et affichage sous les notes. Application Android : versionCode 21.

- [Installation](distribution/INSTALL_PUBLIC.md)
- [Compilation et signature](distribution/RELEASE.md)
- [Données personnelles](PRIVACY.md)
- [Licences](distribution/LICENSE_AUDIT.md)
- [Préparation F-Droid](fdroid/README.md)

## Compilation

Utiliser Flutter 3.47.7 (révision dans distribution/BUILD_ENVIRONMENT.json), Java 17 et le SDK Android, ou les bibliothèques de compilation Linux. Puis :

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build linux --release
bash tool/build_android.sh unsigned
```

Les builds Android sont non signés par défaut. La signature de production est fournie dans un fichier privé externe. Ne jamais publier de clé ni de mot de passe. Les APK d’essai et de production ont des certificats différents : une mise à jour directe entre eux n’est pas possible.

## Cloud

Un serveur compatible Supabase peut être configuré dans l’application. Les migrations SQL sont dans supabase/migrations. Désactiver l’inscription publique et gérer explicitement les invitations et autorisations. Les migrations ne constituent pas une procédure complète d’exploitation du serveur.

## Licence

Code Poulpoints sous MIT, voir LICENSE. Les dépendances conservent leurs licences propres. Le logo officiel est conservé. Poulpoints n’est pas encore distribué par F-Droid ; les fichiers présents préparent sa candidature.
