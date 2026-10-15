# Validation 0.6.0 — 14 octobre 2026

## État de départ

L’utilisateur a confirmé la validation de la 0.5.4 sur Bazzite et Android : reconnexion, échanges et reprise réseau. Cela ne constitue pas une validation des nouveaux rappels/widgets de la 0.6.0.

## Vérifications 0.6.0

- Flutter 3.47.7 / Dart 3.13.5, Fedora 43 dans Distrobox.
- Analyse Flutter sans problème signalé.
- 51 tests Flutter réussis : régressions existantes, réglage des rappels, sérialisation, import invalide, reprogrammation des récurrences et action de widget idempotente.
- 7 tests natifs Android sous Robolectric / API 35 : programmation/remplacement/annulation, notification sans doublon, ancien rappel rejeté, reprise après boot, rendu et filtre du widget, autorisation des actions et conservation de leur révision.
- 5 tests Python du compagnon Linux : échéances, doublons, suppression, échec d’envoi, file durable, permissions du fichier et absence d’interprétation shell des textes.
- Test d’intégration Linux sous Xvfb avec dossiers XDG temporaires : action de widget lue depuis un fichier, validation d’une récurrence, sauvegarde réelle, acquittement et mise à jour du prochain rappel.
- Widget KDE chargé avec Qt/PySide6 dans un profil temporaire : compilation QML, rendu de la liste, lecture du compagnon et commande de validation vers un lanceur fictif vérifiés. Aucun widget ajouté au bureau personnel.
- Installation KDE testée dans des dossiers temporaires ; démarrage du service neutralisé pendant ce test. Structure du paquet vérifiée avec kpackagetool6 et unité contrôlée avec systemd-analyze.
- Compilations Linux release, APK Android ARM64 et Web réussies. APK destiné aux essais, signature de développement.

## Limites

L’émulateur Android installé dans cet environnement a planté pendant son démarrage, avant lancement de Poulpoints. Les tests Robolectric ne remplacent pas la vérification sur téléphone réel des permissions, de l’économie d’énergie et du comportement du lanceur. Il reste également à confirmer les alertes Linux pendant une session réelle avec le compagnon activé.

Aucune connexion à votre cloud réel ni modification de Supabase pendant ce développement. Les nouvelles options sont contenues dans le JSON des tâches et ne demandent pas de migration SQL. Mettre à jour les autres appareils pour éviter qu’une ancienne version supprime les champs qu’elle ne connaît pas.

## Reproduction

```sh
flutter analyze
flutter test --timeout 60s
python3 -m unittest discover -s desktop -v
cd android
./gradlew :app:testDebugUnitTest
```

Le test `integration_test/desktop_bridge_test.dart` écrit des données de test : utiliser uniquement des dossiers XDG temporaires et une session D-Bus isolée, jamais le profil personnel.

## Références techniques

- [Alarmes Android](https://developer.android.com/develop/background-work/services/alarms)
- [Widgets Plasma 6](https://develop.kde.org/docs/plasma/widget/porting_kf6/)
- [Tests Robolectric](https://robolectric.org/getting-started/)
