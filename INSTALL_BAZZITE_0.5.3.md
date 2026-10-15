# Installer et tester Poulpoints 0.5.3 sur Bazzite

Extraire le ZIP à côté du dossier 0.5.2, sans le remplacer, par exemple :

```bash
mkdir -p ~/Téléchargements/poulpoints_053
unzip ~/Téléchargements/Poulpoints_v0.5.3_source.zip -d ~/Téléchargements/poulpoints_053
distrobox enter poulpoints-dev
cd ~/Téléchargements/poulpoints_053/poulpoints_starter
flutter pub get
flutter test
flutter run -d linux
```

Pour Android, dans le même dossier et le même Distrobox :

```bash
bash scripts/build_android_bazzite.sh
```

L'APK ARM64 de test doit apparaître dans `~/Téléchargements/Poulpoints_0.5.3_arm64.apk` si les tests et la compilation réussissent. Conserver les résultats du terminal. La signature Android debug peut différer de l'APK déjà présent ; sauvegarder les tâches avant toute désinstallation.

## Vérifications pratiques

1. Se connecter à Poulapp Cloud sur Linux et Android.
2. Créer une tâche sur Linux **sans cliquer sur synchroniser**. Vérifier dans Paramètres que le statut passe à « Synchronisé à ... ».
3. Avec Poulpoints encore ouvert sur le Pixel, attendre environ une minute ; la tâche doit arriver automatiquement.
4. Modifier la tâche sur le Pixel et attendre quelques secondes. Vérifier sur Linux dans la minute.
5. Couper Internet, modifier une tâche, vérifier sa sauvegarde locale, reconnecter et attendre quelques minutes. La tâche ne doit pas disparaître.
6. Ouvrir Paramètres sur Android et Linux : les groupes Cloud, Sauvegardes, Ancien serveur et Apparence doivent être visibles, mais absents de la barre latérale.
7. Vérifier l'alignement homogène des lignes Toutes, Aujourd'hui, Personnel, Travail, Nouveau projet, Statistiques et Paramètres.

Remarque : en 0.5.3 la connexion doit encore être faite à chaque redémarrage de l'application. La synchronisation automatique fonctionne ensuite, tant que l'application est ouverte. La synchronisation en arrière-plan et la session sécurisée permanente seront traitées séparément.
