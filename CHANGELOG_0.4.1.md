# Poulpoints 0.4.1 — ergonomie mobile

Cette version reprend **exactement le code et les ressources de Poulpoints 0.4.0**, avec deux modifications d'interface. Les modèles (`Task`, `Subtask`, `RecurrenceRule`), les migrations, la base de données et l'API de synchronisation n'ont pas été modifiés.

## Modifications

1. **Création et modification sur téléphone** : à une largeur inférieure à 600 pixels logiques, l'éditeur s'ouvre comme une vraie page Flutter (`MaterialPageRoute`, `Scaffold`) occupant toute la largeur. Les champs défilent avec une marge intérieure de 16 pixels. `Annuler` et `Enregistrer` restent dans une barre au bas de la page, y compris lorsque le clavier réduit la hauteur disponible. Sur écran large, le dialogue d'origine est conservé.
2. **Répétition personnalisée** : les paragraphes d'explication ne sont plus visibles dans le formulaire. Un bouton ⓘ, à côté du libellé « Répétition personnalisée », ouvre une aide ponctuelle fermable avec « Compris ». Le résumé dynamique de la règle et la première échéance restent affichés : ce sont des informations propres à la tâche, pas du texte d'aide.

## Installation et test sur Bazzite / Distrobox

Ne pas supprimer l'ancien projet ou les données de l'application. Extraire l'archive dans un **nouveau dossier** et entrer dans `poulpoints_starter`. Dans `poulpoints-dev` (où Flutter est déjà installé) :

```bash
cd ~/Téléchargements/Poulpoints_v0.4.1/poulpoints_starter
flutter pub get
flutter analyze
flutter test
flutter run -d linux
```

Le source inclut un test de widget spécifique à la largeur mobile et à l'apparition/disparition de l'aide. Pour la construction APK **sur une machine disposant du SDK Android** :

```bash
flutter build apk --debug --target-platform android-arm64
```

Le fichier APK de débogage se trouve alors sous `build/app/outputs/flutter-apk/app-debug.apk`. Vérifier sur téléphone qu'il met bien à jour l'APK 0.4.0 installé (même identifiant d'application, signature de débogage pouvant différer selon la machine). En cas de signature différente, **ne pas désinstaller l'ancienne version sans exporter les données**.

## État de validation de cette archive

Code modifié, cohérence structurelle vérifiée ; **Flutter, les tests Dart et la compilation APK n'ont pas été exécutés dans l'environnement de préparation** (SDK Flutter indisponible). Vérifier avec les commandes ci-dessus avant diffusion. Cette archive contient le code source, pas un APK précompilé.
