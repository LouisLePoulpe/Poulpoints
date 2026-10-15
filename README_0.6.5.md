# Poulpoints 0.6.5 — actualisation des widgets en arrière-plan

La version 0.5.4 a été validée sur Bazzite et Android par l’utilisateur. La validation utilisateur de la 0.6.0 a échoué sur le widget Android. La 0.6.1 corrige son redimensionnement, sa validation en arrière-plan et les accès concurrents au stockage. Le logo officiel et les fonctionnalités existantes sont conservés.

## Nouveauté 0.6.5

Linux : un seul processus Poulpoints reste actif lorsque sa fenêtre est fermée, synchronise le cloud chaque minute et publie les tâches pour KDE. L’installation Bureau ajoute un démarrage sans fenêtre à la connexion de session. Android : WorkManager vérifie le cloud avec réseau disponible, avec un intervalle minimal de 15 minutes, éventuellement retardé par le système. La session cloud doit avoir été mémorisée et le coffre-fort accessible. Ces fonctions concernent Cloud Poulapp/Supabase, pas l’ancien serveur expérimental.

KDE : clic droit sur une zone vide du bureau → Passer en mode édition, puis déplacer le widget par son en-tête. Cocher ouvre encore la fenêtre Poulpoints.

Voir INSTALLATION_0.6.5.md et VALIDATION.md pour l’installation et les limites des essais.

## Nouveauté 0.6.4

Le widget Android suit le thème clair ou sombre du système, avec une palette adaptée au fond, au titre, aux détails et aux boutons. La liste défilante et la validation sans ouvrir l’application sont conservées. Voir VALIDATION.md pour les limites des essais réels.

## Nouveauté 0.6.3

Le widget Android affiche une liste verticale défilante contenant toutes les tâches actives du filtre sélectionné. Le titre Poulpoints et le bouton + restent fixes. Faire glisser dans la liste pour accéder aux tâches suivantes. Les ronds valident toujours en arrière-plan ; toucher le titre Poulpoints ouvre l’application.

## Correctif 0.6.2 conservé

La 0.6.1 Android plantait avant MainActivity : R8 avait supprimé le constructeur sans argument de WorkDatabase_Impl, utilisé au démarrage de WorkManager. La 0.6.2 conserve explicitement ce constructeur dans l’APK optimisé. Le démarrage a été vérifié sur le Pixel 10 réel après mise à jour sans désinstallation.

Contrôle de l’APK final :

    python3 tool/check_android_release.py build/app/outputs/flutter-apk/app-release.apk

Ce contrôle échoue sur la 0.6.1 et passe sur la 0.6.2.

## Nouveautés héritées de la 0.6.1

- Rappel à l’échéance ou 5 minutes, 15 minutes, 1 heure ou 1 jour avant. Date et heure requises. Le réglage est conservé dans la base, les sauvegardes et les données cloud.
- Android : notifications natives, autorisation demandée depuis les paramètres, alarmes restaurées après redémarrage et mise à jour. Horaires précis si autorisés ; sinon, le système peut retarder les alarmes.
- Linux : compagnon local de session qui affiche les rappels même après fermeture de la fenêtre Poulpoints.
- Widget Android : taille initiale 2 × 2, redimensionnable, nombre de lignes adapté à la hauteur, choix de la liste à l’ajout, ajout d’une tâche et validation depuis le widget.
- Widget KDE Plasma 6 : liste défilante, filtre de liste, ajout et validation. Le compagnon n’ouvre aucun port réseau et n’accède à aucun identifiant cloud.
- Sur Android, cocher utilise un traitement en arrière-plan et le même moteur de données que la fenêtre. Le titre et + ouvrent l’application. Sur Linux, cocher ouvre toujours Poulpoints. Une ancienne version d’une tâche ne peut pas valider la nouvelle occurrence d’une récurrence.
- Linux utilise une instance unique par session pour que l’ouverture depuis le widget retrouve la fenêtre existante.

## Installation

Voir [INSTALLATION_0.6.5.md](INSTALLATION_0.6.5.md). Exporter une sauvegarde avant mise à jour et fermer l’ancienne version. Mettre à jour tous les appareils qui modifient des tâches avec rappels : les anciennes versions ne connaissent pas ce champ et peuvent le supprimer en réenregistrant une tâche.

Depuis la 0.6.5, Cloud Poulapp/Supabase se synchronise aussi en arrière-plan sur Android et Linux, selon les délais et conditions décrits ci-dessus. Les rappels utilisent la copie locale et peuvent apparaître sur chaque appareil qui les a reçus et autorisés.

## Fonctions conservées

Tâches, listes, sous-tâches, priorité, date/heure, lieu, notes, filtres, recherche par titre, statistiques et thèmes. Répétitions personnalisées (intervalles, plusieurs jours de semaine et rang dans le mois), sauvegarde locale transactionnelle, export/import et restauration. Cloud Supabase avec conservation sécurisée de la session native.

## Limites

- Le widget Linux fourni vise KDE Plasma 6, pas GNOME ni les autres bureaux.
- Android : les actions passent par une file persistante ; si un formulaire reste ouvert ou qu’une sauvegarde échoue, la validation attend. Linux : cocher ouvre l’application.
- Linux : session graphique ouverte et compagnon installé requis ; pas de réveil d’un ordinateur éteint. Contrôle des échéances toutes les 15 secondes et rattrapage des rappels manqués de moins de 24 heures.
- Android : pas de garantie après arrêt forcé, restriction système ou refus des notifications. Un lancement de l’application rétablit la programmation. Sans autorisation d’alarme exacte, les rappels peuvent être retardés.
- Pas encore de report/snooze ni de notifications Web ou Windows.
- Le démarrage Web hors ligne, Windows, les tags, exceptions de récurrence, résolution guidée des conflits et publication F-Droid restent à développer.
- APK signé avec une clé de développement. Application MIT, sans Firebase ni services Google ajoutés pour ces fonctionnalités.

Voir [VALIDATION.md](VALIDATION.md) pour les tests et les limites de validation.

Android : revenir à l’accueil programme également une tentative d’envoi persistante avec réseau disponible, afin de conserver les modifications faites juste avant la fermeture de la fenêtre.
