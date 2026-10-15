# Installation Poulpoints 0.7.1

Exporter une sauvegarde depuis chaque appareil avant la mise à jour. Mettre à jour Android et Linux avant de modifier des tâches avec les nouveaux champs. Ne pas désinstaller Poulpoints et ne pas effacer ses données.

## Pixel / Android ARM64

Installer Poulpoints_v0.7.1_Android_ARM64_essai.apk par-dessus la version actuelle. Il conserve la signature de développement utilisée lors des essais. Ouvrir une fois l’application après mise à jour. Les notifications et widgets conservent leurs autorisations.

## Bazzite KDE

Extraire Poulpoints_v0.7.1_Linux_Bazzite_KDE.tar.gz, puis depuis le terminal Bazzite, hors Distrobox :

```sh
cd /chemin/vers/Poulpoints_v0.7.1
bash desktop/install.sh bundle
```

La fenêtre fermée de la 0.7.0 peut laisser un processus actif. Avant de démarrer la nouvelle version, terminer l’ancienne instance Poulpoints via le moniteur système après avoir enregistré toute modification. Puis lancer Poulpoints depuis le menu. Le compagnon démarre automatiquement à la prochaine ouverture de session.

Le widget KDE installé peut conserver son ancien code en mémoire. Pour recharger uniquement ce widget, le retirer et le réajouter ; cela ne supprime aucune tâche, mais peut réinitialiser sa position et son filtre. Sinon, attendre la prochaine reconnexion de session. Cocher une tâche doit alors rester silencieux.

## Nouveaux gestes

- Projet : icône de corbeille à côté de son nom, puis choisir où déplacer ses tâches.
- Étiquettes : dans le formulaire, séparer les mots par des virgules ; utiliser la recherche pour les retrouver.
- Répétition : ouvrir les détails pour ignorer ou déplacer l’occurrence courante.
- Rappels : sélectionner plusieurs délais dans le formulaire. « Me rappeler dans 10 minutes » conserve l’échéance ; le bouton de notification Android fait la même chose.
- Conflit cloud : lancer la synchronisation manuelle depuis les paramètres pour comparer et choisir les versions. Exporter une sauvegarde avant une résolution importante. Une nouvelle modification distante peut nécessiter un nouveau choix.

## Compilation dans Distrobox

```sh
distrobox enter poulpoints-dev
cd /chemin/vers/poulpoints_starter
export PATH="$HOME/flutter/bin:$PATH"
bash tool/build_android.sh test
flutter build linux --release
```

Le script Android exécute l’analyse, les tests, la compilation et le contrôle des constructeurs dans le DEX. Les modes `unsigned` et `production` sont décrits dans distribution/RELEASE.md. Les binaires de cette livraison sont destinés aux essais, pas à une diffusion publique signée en production.
