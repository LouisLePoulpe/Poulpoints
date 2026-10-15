# Poulpoints 0.5.0-dev.2 — correctif de la fenêtre cloud

## Correction

- Le formulaire « Poulapp Cloud — connexion » possède désormais ses propres contrôleurs de texte (`StatefulWidget`).
- Les contrôleurs sont libérés quand le formulaire est réellement démonté, pas immédiatement à la fin de `showDialog`. Cela vise le plantage Flutter `_dependents.isEmpty` observé après validation du formulaire sous Linux.
- Les champs requis sont vérifiés dans le formulaire. La connexion HTTPS et la clé publique restent validées par le client Supabase existant.
- Deux tests de widget couvrent la validation et l'annulation du dialogue, y compris la fermeture animée.
- Le modèle local, les tâches, la structure Supabase et le logo officiel n'ont pas été modifiés.

## Statut

**Correctif proposé et non encore validé par une compilation Flutter dans cet environnement.**
Ne pas considérer la connexion Supabase ou la synchronisation cloud comme testées de bout en bout.

## Tester avec Bazzite

Depuis Distrobox `poulpoints-dev`, dans le dossier extrait :

```sh
flutter pub get
flutter test test/cloud_login_dialog_test.dart
flutter test
flutter run -d linux
```

Si le plantage persiste, relancer `flutter run -d linux --verbose` et transmettre le **premier** message d'exception et la pile associée (en masquant adresse e-mail et identifiants).

**Avant toute synchronisation**, exporter une sauvegarde JSON des tâches existantes et conserver séparément la version 0.4.1.
