# Poulpoints 0.6.1 — mise à jour corrective

## Android : conserver les données existantes

1. Si la 0.6.0 affiche « Modifications non sauvegardées », utiliser **Copier une sauvegarde** et conserver immédiatement le texte dans un fichier privé. Les modifications restées seulement en mémoire ne peuvent pas être récupérées automatiquement par une mise à jour.
2. Installer **Poulpoints_v0.6.1_Android_ARM64_essai.apk** par-dessus l’application existante. Ne pas désinstaller Poulpoints et ne pas effacer ses données. L’APK utilise la même signature de développement que celui de la 0.6.0 fourni ici. Si Android refuse la mise à jour, conserver l’installation et relever le message.
3. Ouvrir Poulpoints une fois et vérifier les tâches enregistrées. Si la sauvegarde exportée contient des modifications absentes, comparer les données avant de l’importer : une restauration remplace les données locales.
4. Retirer uniquement l’ancien widget de l’écran d’accueil, puis ajouter de nouveau le widget **Poulpoints**. Cela permet au lanceur de relire les dimensions corrigées ; les tâches restent dans l’application.
5. Le widget propose 2 × 2 cases au départ, avec réduction/agrandissement dans les deux directions. La taille exacte dépend de la grille du lanceur. Maintenir le widget appuyé puis utiliser les poignées de redimensionnement proposées par le lanceur.

**Le rond termine une tâche en arrière-plan.** Il ne demande plus l’ouverture de la fenêtre Poulpoints. Le titre ouvre l’application ; le bouton + ouvre la création. Le nombre de lignes visibles s’adapte à la hauteur. Les autres tâches restent accessibles dans l’application.

Une validation peut rester brièvement « Enregistrement… » pendant le démarrage du traitement. Si un formulaire est ouvert, fermer ou enregistrer ce formulaire pour laisser passer l’action. En cas d’erreur de stockage, la commande reste en attente et l’application conserve son contrôle contre les écrasements.

La synchronisation cloud conserve son fonctionnement au premier plan : ouvrir Poulpoints pour propager ou recevoir les changements. La validation du widget actualise les données et rappels locaux. Android peut différer un travail d’arrière-plan selon ses restrictions ; après un arrêt forcé dans ses paramètres, rouvrir l’application.

## Vérification sur le Pixel

- Ajouter le nouveau widget ; le réduire puis l’agrandir.
- Depuis l’écran d’accueil, terminer une tâche simple : la fenêtre Poulpoints ne doit pas s’ouvrir et la tâche doit disparaître du widget.
- Ouvrir Poulpoints : la tâche doit apparaître dans Terminées. Créer ou modifier une autre tâche, fermer puis rouvrir : aucune erreur de sauvegarde ne doit apparaître.
- Refaire le test après avoir retiré Poulpoints des applications récentes (sans arrêt forcé).
- Terminer une tâche récurrente avec un rappel : une seule occurrence doit avancer, le rappel doit suivre la nouvelle échéance.
- Tester deux appuis rapides sur le même rond : une seule validation de cette occurrence.
- Ouvrir Poulpoints sur Android et Bazzite pour vérifier la propagation cloud.

La 0.6.1 a été compilée et testée automatiquement ; elle n’est pas encore validée sur le téléphone réel.

## Bazzite / Distrobox : compiler les sources

Extraire l’archive source dans un nouveau dossier. Fermer les anciennes fenêtres Poulpoints.

```sh
distrobox enter poulpoints-dev
cd /chemin/vers/poulpoints_starter
flutter pub get
flutter analyze
flutter test
flutter build linux --release
```

Si les dépendances Linux manquent dans le conteneur :

```sh
sudo dnf install libsecret-devel jsoncpp-devel
```

Pour lancer :

```sh
./build/linux/x64/release/bundle/poulpoints
```

Pour installer le compagnon et le widget KDE, depuis le terminal **Bazzite hôte**, dans le dossier source :

```sh
bash desktop/install.sh
```

Le widget KDE conserve son comportement : cocher ouvre l’application. Le correctif de validation sans fenêtre concerne Android.

## Compiler Android dans Distrobox

Avec le SDK Android déjà configuré :

```sh
flutter pub get
flutter build apk --release --target-platform android-arm64
```

Résultat : `build/app/outputs/flutter-apk/app-release.apk`. Conserver la même clé de signature pour mettre à jour une installation existante. Ce projet utilise encore une signature de développement : l’APK fourni est une version d’essai, pas une publication F-Droid.
