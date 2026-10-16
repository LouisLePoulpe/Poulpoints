# Pièces jointes — 0.8.0

Ouvrir une tâche enregistrée, puis « Ajouter une pièce jointe » dans ses détails. Choisir un fichier dans le sélecteur du téléphone ou de l’ordinateur. La connexion cloud est nécessaire. Toucher le nom pour télécharger/ouvrir le fichier ; la corbeille retire sa copie cloud.

Limites : 10 Mo/fichier, 10 fichiers/tâche, 100 Mo/compte. Les fichiers sont privés, séparés du texte des tâches et ne font pas partie des exports JSON. Une tâche récurrente ne conserve pas les fichiers de l’occurrence précédente.

## Suppression

Dès qu’une complétion/suppression de tâche arrive au serveur, un déclencheur marque les fichiers à supprimer et envoie une requête asynchrone au service Storage après validation de la transaction. Aucun délai périodique n’est attendu pour les fichiers déjà transférés. La sauvegarde des tâches ne dépend pas de la disponibilité de Storage. Une file durable est réessayée chaque minute. Les transferts encore en cours attendent deux minutes avant nettoyage ; les transferts abandonnés expirent après quinze minutes.

Le fichier original de l’appareil reste intact. Une copie déjà téléchargée par un utilisateur ne peut pas être effacée à distance. Rouvrir une tâche ne restaure pas les pièces jointes supprimées. Les suppressions hors ligne attendent la synchronisation.

## Installation serveur

Appliquer les migrations dans l’ordre et déployer `supabase/functions/poulpoints-attachments/index.ts` avec la vérification JWT activée. La clé de service reste exclusivement dans l’environnement serveur. Le bucket et les tables ne sont pas accessibles directement aux clients : le service vérifie l’utilisateur, son accès Poulpoints et la propriété de la tâche.

Configurer dans `private.poulpoints_attachment_gc_config` l’endpoint de cette fonction et le JWT public anon du projet pour la passerelle JWT. Le secret de nettoyage distinct est généré par la migration et reste privé. Sans cette configuration, le traitement automatique est inactif. Aucun secret ni identifiant de session ne doit être ajouté au dépôt.

Les migrations de correction remplacent les arguments SQL par la notation nommée `=>`. L’absence de politiques RLS sur les deux tables techniques est volontaire : seuls les traitements serveur ont des droits, pas les clients authentifiés.

## Vérifications

74 tests Flutter réussis, dont complétion unique, récurrence, réouverture et sérialisation du cycle des pièces jointes. `tool/test_attachments_database.sh` teste sur base locale jetable les transitions et le contrôle de propriétaire. Compilation Android arm64 et Linux réussie. Le nettoyage serveur a aussi été sollicité via son authentification privée ; le fonctionnement réel a été confirmé par l’utilisateur le 16 octobre 2026.
