# Poulpoints 0.6.5 — installation

## Android

Installer Poulpoints_v0.6.5_Android_ARM64_essai.apk par-dessus l’existant, sans désinstallation ni effacement, puis ouvrir Poulpoints une fois. Le compte Cloud Poulapp doit être connecté avec session mémorisée. Le travail périodique est ensuite enregistré auprès d’Android et se rétablit après redémarrage.

L’actualisation cloud se produit au mieux toutes les 15 minutes, parfois plus tard en veille ou économie de batterie. Une fermeture forcée via les paramètres Android empêche les travaux jusqu’à réouverture. Les rappels déjà programmés utilisent un mécanisme distinct. L’APK conserve la signature de développement, ce n’est pas une publication F-Droid.

## Bazzite / KDE

Extraire Poulpoints_v0.6.5_Linux_Bazzite_KDE.tar.gz. Depuis un terminal Bazzite (hors Distrobox), entrer dans le dossier extrait puis :

```sh
bash desktop/install.sh bundle
```

Le conteneur `poulpoints-dev` doit déjà exister. Un lanceur Poulpoints est ajouté au menu ; le compagnon démarre sans fenêtre à la prochaine connexion au bureau. Pour le démarrer immédiatement :

```sh
"${XDG_DATA_HOME:-$HOME/.local/share}/poulpoints-desktop/launch.sh" --background
```

Fermer la fenêtre laisse Poulpoints actif pour synchroniser environ chaque minute. Ouvrir Poulpoints réutilise ce processus. Le coffre-fort doit être déverrouillé et la session cloud mémorisée. Pour désactiver le démarrage automatique, désactiver « Poulpoints — synchronisation » dans les paramètres de démarrage automatique KDE ; quitter ensuite le processus Poulpoints via le moniteur système. Le service de rappels est indépendant.

Pour déplacer/redimensionner le widget : clic droit sur le bureau → Passer en mode édition. Le widget relit la projection locale toutes les cinq secondes. Cocher ouvre encore l’application.

## Compiler depuis les sources

```sh
distrobox enter poulpoints-dev
cd /chemin/vers/poulpoints_starter
flutter pub get
flutter analyze
flutter test
flutter build linux --release
flutter build apk --release --target-platform android-arm64
python3 tool/check_android_release.py build/app/outputs/flutter-apk/app-release.apk
```

Pour Android, le SDK doit être configuré. Installer le compagnon depuis Bazzite avec `bash desktop/install.sh build/linux/x64/release/bundle` dans le dossier source. L’ancien serveur expérimental ne bénéficie pas de cette synchronisation automatique.

Android : revenir à l’accueil programme également une tentative d’envoi persistante avec réseau disponible, afin de conserver les modifications faites juste avant la fermeture de la fenêtre.
