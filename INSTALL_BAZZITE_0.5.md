# Tester le prototype 0.5.0-dev.1 sur Bazzite

Version expérimentale, compilations non vérifiées par l'auteur de l'archive.
Ne supprimez pas la 0.4.1 et sauvegardez vos tâches JSON avant tout test.

1. Enregistrer l'archive Poulpoints_v0.5.0_dev1_source.zip dans Téléchargements.
2. Ouvrir un terminal sur Bazzite :

    mkdir -p ~/Téléchargements/poulpoints_050_test
    unzip ~/Téléchargements/Poulpoints_v0.5.0_dev1_source.zip -d ~/Téléchargements/poulpoints_050_test
    distrobox enter poulpoints-dev
    cd ~/Téléchargements/poulpoints_050_test/poulpoints_starter
    flutter pub get
    flutter test
    flutter run -d linux

3. En cas d'erreur, joindre la sortie exacte de la première commande en échec.
4. Dans le menu, sélectionner « Se connecter au cloud Poulapp » puis renseigner
   l'URL du projet, la clé PUBLIQUE dans les réglages API Supabase, et les
   identifiants utilisateur de Supabase Auth. Ne jamais saisir de clé secrète.
5. Pour le premier essai, cliquer sur « Copier une sauvegarde » et conserver
   le JSON en lieu sûr ; puis lancer « Synchroniser Poulapp Cloud ».
6. Tester sur un petit jeu de tâches avant les données réelles. Vérifier la
   liste à partir du tableau de bord Supabase, puis sur un autre appareil.
7. Après validation Linux, compiler sur Android :

    flutter build apk --release --split-per-abi

   APK Pixel : build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

L'APK de test peut utiliser une clé de signature différente de la version
installée. Sauvegarder avant remplacement. Aucune publication F-Droid à ce stade.

Voir CLOUD_0.5.0_PREVIEW.md pour les limitations connues :
conflits non résolus automatiquement, absence de session persistante après
fermeture, réseau intermittent et déconnexions non testés.
