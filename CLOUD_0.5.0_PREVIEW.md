# Poulpoints 0.5.0-dev.1 — Expérimentation Supabase (NON VALIDÉE)

Cette version est destinée aux essais sur une copie de l'application et une
base Supabase de test. Elle n'a pas été compilée ni testée avec Flutter dans
l'environnement de livraison. **Ne l'utilisez pas sur les seules copies de vos
tâches importantes.**

## Nouveautés

- Connexion Supabase par e-mail + mot de passe, avec vérification d'une ligne
  autorisée dans `poulapp_access` (app_id `poulpoints`).
- URL Supabase et **clé publique publishable / anon** saisies au lancement,
  jamais de clé secret/service_role ni de mot de passe de base de données.
- Mot de passe, access token et refresh token **en mémoire uniquement** :
  nouvelle connexion nécessaire après fermeture de l'application.
- Synchronisation manuelle des tâches, sous-tâches, récurrences, projets et
  suppressions logiques à travers les tables SQL des migrations 001 et 002.
- Fusion en trois voies avec empreintes canoniques et révisions serveur :
  conflit bloqué sans écraser la copie locale, mise à jour conditionnelle par
  numéro de révision, pas d'UPSERT inconditionnel.
- Après la **première synchronisation manuelle réussie**, synchronisation
  automatique tant que l'application reste ouverte : 3 secondes après une
  modification, toutes les 2 minutes, et au retour au premier plan.
- Checkpoint de synchronisation lié au compte et à l'adresse Supabase,
  stockage local transactionnel antérieur conservé.
- Ancien serveur Python expérimental conservé comme mode distinct, mais
  désactivé tant qu'une session Supabase est ouverte.

## Précautions

1. Exporter le JSON sur chaque appareil avant d'essayer ce prototype.
2. **Ne pas remplacer son application Android habituelle** sans sauvegarde.
3. Sur deux appareils, commencer par des tâches de test dans le cloud.
4. Si des données portant un même identifiant divergent, le moteur refuse la
   synchronisation, n'efface rien localement et demande une intervention.
5. Une coupure réseau au milieu d'une série d'écritures peut laisser une
   synchronisation partielle dans Supabase ; les opérations sont conditionnées
   à la révision et les conflits doivent être résolus manuellement.
6. Il n'existe pas encore d'interface de résolution de conflit.
7. La première synchronisation doit être déclenchée manuellement après export.
8. Il n'y a pas de sauvegarde automatisée du côté Supabase Free.
9. L'application ne dispose pas d'un keychain sécurisé permettant de conserver
   les sessions ; le cloud automatique reste donc limité à la session ouverte.
10. L'usage de l'API publique d'un Supabase tiers peut consommer du quota, même
    avec inscription désactivée et RLS. Ne pas intégrer l'URL du projet privé
    Poulapp dans une version publique F-Droid.
11. La clé publique et l'URL sont stockées dans les préférences pour le confort
    de configuration ; elles ne doivent jamais être confondues avec une clé
    administrateur.

## Mise en place sur un projet Supabase

Exécuter les migrations 001 et 002 sous `supabase/migrations/`
(si elles n'ont pas déjà été appliquées au projet Supabase). Ajouter pour chaque compte autorisé
une entrée `(user_id, 'poulpoints')` dans `public.poulapp_access`.
L'application utilise uniquement les tables `poulpoints_*`, et la même base
Supabase peut héberger les autres applications Poulapp avec leurs propres tables
et règles RLS.

Dans le Dashboard Supabase, retrouver la **Project URL** et la **publishable key**
(section API Keys). Ces deux valeurs sont publiques, mais la clé ne doit pas
être une `service_role` ou `sb_secret_*`. Les identifiants utilisateur ne sont
pas ceux du compte administrateur Supabase.

Dans Poulpoints : menu -> Se connecter au cloud Poulapp -> URL / clé publique /
e-mail / mot de passe -> Se connecter. Exporter ensuite JSON et sélectionner
« Synchroniser Poulapp Cloud » pour la première synchronisation.

Pour compiler sous Bazzite, entrer d'abord dans `distrobox enter poulpoints-dev` :

    flutter pub get
    flutter test
    flutter run -d linux
    flutter build apk --release --split-per-abi

Le code Supabase a été écrit sans téléchargement de nouvelle dépendance Flutter
(il utilise `http` déjà présent). Le projet reste sous licence MIT et conserve
exactement le logo officiel bleu fourni.
