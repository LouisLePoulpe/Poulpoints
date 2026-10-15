# Distribution Poulpoints 0.7.1

Les sources sont sous licence MIT. Le logo officiel est inclus sans modification. Les dépendances Dart sont verrouillées dans pubspec.lock ; la version de compilation est consignée dans BUILD_ENVIRONMENT.json.

## APK d’essai compatible avec les installations actuelles

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
POULPOINTS_TEST_SIGNING=1 flutter build apk --release --target-platform android-arm64
python3 tool/check_android_release.py build/app/outputs/flutter-apk/app-release.apk
```

La signature de développement ne doit pas devenir la signature publique de production. La livraison d’essai reste compatible avec les APK précédents, sans désinstallation.

## Production

Conserver la clé et ses sauvegardes chiffrées hors du dépôt et des archives. Copier signing.properties.example dans un dossier privé, renseigner les quatre champs puis :

```sh
POULPOINTS_SIGNING_PROPERTIES=/chemin/prive/signing.properties flutter build apk --release --target-platform android-arm64
```

Sans ces variables, la release est non signée, notamment pour la compilation par F-Droid. Ne jamais publier le fichier d’exemple comme une configuration utilisable. Une clé de production a été créée hors du dépôt. Son empreinte publique est dans ANDROID_SIGNING_CERTIFICATE.sha256. Une copie chiffrée indépendante du disque de travail reste à réaliser.

Changer de certificat empêche une mise à jour directe des APK d’essai existants. Avant la première distribution publique, choisir la stratégie de signature et prévoir export/import pour les testeurs. Ne pas désinstaller la version personnelle sans sauvegarde.

## Publication à terminer

Le dépôt public prévu est https://github.com/LouisLePoulpe/Poulpoints. Y placer le contenu de poulpoints_starter (sans caches, données ni secrets), vérifier les notices des dépendances, figer le commit et créer le tag v0.7.1 après validation. Publier sources, binaires, instructions et empreintes SHA-256. Les captures publiques doivent utiliser des tâches fictives. Aucun dépôt ni envoi public n’a été effectué.

## Linux

Compiler dans Distrobox : `flutter build linux --release`.
Installer depuis Bazzite : `bash desktop/install.sh build/linux/x64/release/bundle`.
Le compagnon démarre sans fenêtre à la connexion de session. Fermer la fenêtre laisse la synchronisation active. Les validations acquises de la 0.6.5 ne sont pas à refaire ; vérifier seulement les fonctions nouvelles de la 0.7.1.
