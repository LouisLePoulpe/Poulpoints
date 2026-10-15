# Installer Poulpoints 0.6.0

La 0.5.4 a été validée par l’utilisateur. Exporter une sauvegarde et fermer l’ancienne version avant de mettre à jour. Conserver cette sauvegarde dans un fichier privé. Mettre à jour Linux, Android et Web avant de modifier des tâches contenant des rappels.

## Android

Installer l’APK ARM64 d’essai par-dessus l’application existante. Ne pas désinstaller en cas de refus de signature sans sauvegarde préalable. Dans Poulpoints : **Paramètres → Rappels et widgets → Activer les notifications**. Pour une meilleure ponctualité, utiliser aussi **Autoriser les horaires précis sur Android**, autoriser Poulpoints puis revenir dans l’application.

Créer une tâche avec date, heure et rappel. Dans les options du lanceur Android, ajouter le widget **Poulpoints**, puis choisir toutes les listes ou une liste existante. Le widget affiche au maximum cinq tâches, prioritaires puis par échéance. Selon le lanceur, un appui long permet de reconfigurer la liste. Cocher une tâche ouvre Poulpoints pour l’enregistrer. Le bouton + ouvre le formulaire.

Les alarmes sont rétablies après un redémarrage Android. Si l’application est arrêtée de force dans les paramètres Android, la rouvrir. Les réglages d’économie d’énergie et les permissions peuvent retarder ou empêcher les notifications. Les alertes utilisent la dernière copie locale reçue : ouvrir Poulpoints pour récupérer les changements cloud.

## Bazzite KDE — archive prête à utiliser

Extraire `Poulpoints_v0.6.0_Linux_Bazzite_KDE.tar.gz` dans un nouveau dossier. Depuis un terminal **Bazzite hôte**, placé dans le dossier extrait :

```sh
bash Installer-Bureau.sh
```

Ce script installe l’application pour ton utilisateur, le composant KDE et le service local de rappels. Il utilise ton conteneur existant `poulpoints-dev` pour exécuter l’application. Il ne modifie pas les paquets système Bazzite et ne change pas la disposition du bureau.

Lancer ensuite :

```sh
bash Lancer-Poulpoints.sh
```

Sur le bureau KDE : clic droit → mode édition / ajouter des composants graphiques → rechercher **Poulpoints** → déposer le widget sur le bureau. La liste se rafraîchit toutes les cinq secondes. Le filtre permet de choisir une liste. Cocher ouvre l’application et enregistre la validation ; + ouvre la création.

Le compagnon de rappels démarre avec la session graphique et continue après fermeture de la fenêtre. Il ne synchronise pas le cloud. Vérifier son état :

```sh
systemctl --user status poulpoints-reminders.service
```

Pour arrêter les rappels Linux :

```sh
systemctl --user disable --now poulpoints-reminders.service
```

Pour retirer le widget installé, le supprimer du bureau puis exécuter :

```sh
kpackagetool6 --type Plasma/Applet --remove org.poulapp.poulpoints
```

Ces opérations ne suppriment pas les tâches. Les fichiers du compagnon restent dans `${XDG_DATA_HOME:-$HOME/.local/share}/poulpoints-desktop`. Éviter de lancer une ancienne version simultanément.

## Depuis les sources dans Distrobox

```sh
distrobox enter poulpoints-dev
cd /chemin/vers/poulpoints_starter
sudo dnf install libsecret-devel jsoncpp-devel
flutter pub get
flutter analyze
flutter test --timeout 60s
flutter build linux --release
```

Puis, depuis le terminal **Bazzite hôte**, dans le même dossier source :

```sh
bash desktop/install.sh
```

## Vérification sur tes appareils

1. Créer une tâche à quelques minutes dans le futur et sélectionner « À l’échéance ».
2. Vérifier sa présence dans le widget ; fermer la fenêtre sans arrêter de force Android.
3. Vérifier l’alerte. Modifier ensuite une échéance et vérifier l’annulation de l’ancien rappel.
4. Cocher une tâche dans le widget et vérifier la sauvegarde après réouverture.
5. Pour une récurrence, vérifier qu’un seul clic avance d’une occurrence et reprogramme son rappel.
6. Vérifier l’échange entre les appareils en ouvrant l’application sur chacun.

Les rappels de moins de 24 heures de retard sont rattrapés à la remise en service ; les plus anciens ne sont pas envoyés en rafale. Un appareil éteint ne peut pas notifier.
