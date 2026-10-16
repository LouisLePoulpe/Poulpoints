# Exploitation du cloud Poulapp

Le cloud partagé peut contenir d’autres applications Poulapp. Les sauvegardes doivent être privées et couvrir aussi les comptes et autorisations. Aucun identifiant administrateur n’est inclus dans ce dépôt.

## Accès

Configurer libpq dans des fichiers privés `~/.pg_service.conf` et `~/.pgpass` (permissions 600), depuis la connexion fournie par Supabase. Ne pas transmettre le mot de passe dans une conversation, une URL de commande ou un commit. Le client PostgreSQL doit être de version au moins égale à celle du serveur. Utiliser une connexion avec vérification TLS selon les instructions Supabase.

## Contrôle ponctuel

`psql -X -v ON_ERROR_STOP=1 -f ops/cloud_health.sql` renvoie uniquement des compteurs, la taille totale de la base et l’activation des protections RLS. Vérifier également dans le tableau de bord Supabase les quotas d’egress, d’authentification et les erreurs : ces métriques ne peuvent pas être déduites de la taille PostgreSQL. Seuils proposés : avertissement à 50 %, action à 75 %, urgence à 90 % du quota applicable.

## Sauvegarde

Définir PGSERVICE, PGDATABASE et POULPOINTS_BACKUP_DIR, puis exécuter `bash ops/backup_database.sh`. Le script crée un dossier privé, vérifie la structure du dump et calcule son empreinte. Un fichier `.partial` n’est pas une sauvegarde terminée. Le script ne supprime aucune sauvegarde précédente.

Le dump contient des données personnelles et peut contenir des données d’autres applications. Le placer sur un volume chiffré et conserver une copie hors de l’ordinateur. Proposition de rétention à valider : 7 quotidiennes, 4 hebdomadaires, 3 mensuelles. Aucun calendrier automatique ni alerte n’est encore activé.

Le dump logique n’inclut pas les objets binaires Supabase Storage ni les réglages du projet (SMTP, OAuth, restrictions réseau, etc.). Poulpoints utilise désormais le bucket privé `poulpoints-attachments`. Les fichiers ne sont pas inclus dans le dump SQL. Une restauration de métadonnées seule ne restaure pas les fichiers ; ne pas présenter ce dump comme une sauvegarde complète des pièces jointes. Documenter ces réglages séparément. Les rôles globaux nécessitent aussi une sauvegarde administrative adaptée.

## Restauration

Ne jamais restaurer dans le projet en service pour faire un test. Créer une instance Supabase de test compatible, conserver sa configuration privée distincte et suivre la procédure officielle. Les schémas et extensions gérés Supabase peuvent nécessiter des adaptations : ne pas appliquer aveuglément un dump intégral à un PostgreSQL vide.

Vérifier les nombres d’enregistrements, les marqueurs de suppression, les révisions, les autorisations, puis la connexion et les échanges d’un compte de test. Un essai avec des données fictives ne valide pas la restauration des données du serveur réel.

Références :
- https://supabase.com/docs/guides/platform/backups
- https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore

## Sauvegardes chiffrées et contrôle périodique

`backup_cloud.py --config CHEMIN_PRIVE` exporte la base du projet Supabase
(format pg_dump) et les objets du bucket privé `poulpoints-attachments`.
La base exportée couvre le projet partagé, y compris ses autres applications ;
les fichiers Storage sauvegardés couvrent uniquement Poulpoints.
La configuration et le mot de passe de chiffrement restent hors du dépôt.
Seules les archives chiffrées et leurs empreintes sont déposées dans kDrive.
Les fichiers temporaires en clair restent dans un répertoire privé local.

`verify_cloud_backup.py ARCHIVE --passphrase-file FICHIER_PRIVE` déchiffre
l'archive, contrôle les empreintes, restaure les trois tables Poulpoints dans
une base PostgreSQL locale jetable et vérifie les fichiers référencés.
Ce test ne modifie pas le serveur et ne constitue pas un test de restauration
complète des comptes Auth, des autres applications ou du service Storage.

`install_backup_timer.sh` n'active les sauvegardes quotidiennes et les contrôles
horaires qu'après réussite d'une sauvegarde réelle et du test de restauration.
Ces opérations fonctionnent lorsque cet ordinateur et sa session sont disponibles.
Vérifier séparément que kDrive a effectivement envoyé les archives en ligne.
Conserver le mot de passe de chiffrement dans un gestionnaire de mots de passe
indépendant : une archive seule ne suffit pas pour restaurer.

Le contrôle surveille la taille de la base, le volume des pièces jointes,
les suppressions en retard et l'ancienneté de la dernière sauvegarde.
Il ne remplace pas le suivi des quotas de trafic et de facturation Supabase.
Les archives sont conservées sans suppression automatique ; elles peuvent donc
contenir des pièces jointes supprimées depuis dans l'application. Définir une
politique de conservation avant une exploitation prolongée.
