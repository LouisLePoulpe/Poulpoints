# Validation Poulpoints 0.8.7 (build 28)

Renommage et réorganisation des sous-tâches, à partir de la 0.8.6.

## Choix technique

Les sous-tâches restent une liste `{id, title, done}` dans la tâche (Sembast en local, `payload jsonb` dans Supabase, export JSON). L’ordre est le rang dans cette liste, qui était déjà enregistré, exporté et synchronisé. Il n’y a donc ni nouveau champ, ni migration locale, ni migration SQL : une 0.8.6 qui reçoit une tâche réordonnée l’affiche dans le nouvel ordre sans erreur. Un champ `position` aurait cassé la synchronisation des 0.8.6 : elles l’auraient supprimé à la lecture, puis leur vérification d’empreinte aurait échoué.

Les conflits restent gérés au niveau de la tâche : si deux appareils modifient la même tâche entre deux synchronisations, la boîte de dialogue existante demande quelle version garder. Rien n’est écrasé automatiquement.

## Validation automatique

- `flutter analyze` : aucun problème.
- `flutter test` : 110 tests réussis (91 existants et 19 nouveaux dans `test/subtask_order_test.dart`).

## Tests manuels sur appareils réels

Avant de commencer : exporter une sauvegarde JSON sur chaque appareil.

- [ ] Mise à jour par-dessus la 0.8.6 (Linux puis Android) : tâches, sous-tâches, ordre, session cloud et projet par défaut intacts.
- [ ] Renommer une sous-tâche en touchant son intitulé : texte nettoyé, état coché conservé.
- [ ] Renommer avec un intitulé vide ou seulement des espaces : message affiché, ancien intitulé conservé.
- [ ] Annuler un renommage (Échap sous Linux, retour ou Annuler sous Android) : aucun changement.
- [ ] Réordonner par glisser-déposer (poignée) sous Android, synchroniser, puis vérifier l’ordre sous Linux.
- [ ] Réordonner avec le menu ⋮ (Monter / Descendre) sous Linux, synchroniser, puis vérifier sous Android.
- [ ] Réordonner dans l’écran « Modifier la tâche » (poignée et menu ⇅), enregistrer, rouvrir.
- [ ] Réordonner hors ligne, revenir en ligne : l’ordre se propage.
- [ ] Modifier la même tâche sur les deux appareils hors ligne : la boîte de conflit apparaît et la version choisie est conservée.
- [ ] Cocher une sous-tâche : elle garde sa place.
- [ ] Ajouter une sous-tâche : elle arrive à la fin.
- [ ] Tâche récurrente avec sous-tâches renommées et réordonnées : après « Terminer » ou « Ignorer cette occurrence », mêmes intitulés, même ordre, sous-tâches décochées.
- [ ] Export puis import JSON : ordre identique. Import d’une ancienne sauvegarde 0.8.x : fonctionne.
- [ ] Widgets Android et KDE après redémarrage : tâches affichées, couleurs de retard correctes, aucun conflit de sauvegarde quand on termine une tâche depuis le widget juste après un renommage ou un réordonnancement.
- [ ] Un appareil resté en 0.8.6 se synchronise sans erreur et affiche le nouvel ordre.
