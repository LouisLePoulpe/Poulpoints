# Poulpoints 0.5.2 — Essai Android / Synchronisation Supabase

## Contenu et statut

- Code fonctionnel basé sur **Poulpoints 0.5.0-dev.2**, y compris le correctif de dialogue cloud.
- Version Android passée à **0.5.2 (build 10)** pour permettre la mise à jour de la 0.4.1 (build 7) et du dev.2 (build 9) si la signature correspond.
- **Aucun APK précompilé dans cette archive**. Le script génère un APK depuis la machine Bazzite déjà configurée avec Flutter et le SDK Android.
- La synchronisation est expérimentale : aucun essai de bout en bout Pixel ↔ Linux n'a encore été réalisé.

## Compilation depuis Bazzite

1. Décompresser l'archive dans `~/Téléchargements/poulpoints_052/` (le dossier `poulpoints_starter` se trouve dedans).
2. Ouvrir un terminal, puis :

```bash
distrobox enter poulpoints-dev
cd ~/Téléchargements/poulpoints_052/poulpoints_starter
bash scripts/build_android_bazzite.sh
```

Le script lance `flutter pub get`, `flutter test` et `flutter build apk --release --split-per-abi`. Il conserve ainsi la convention de codes de version des précédents APK séparés par architecture (indispensable pour les mises à jour Android).
Il copie l'APK terminé à :

`~/Téléchargements/Poulpoints_0.5.2_arm64.apk`

Ce fichier peut être transféré sur Android et ouvert pour installation.

## Mise à jour et signature

L'application Android utilise `org.poulapp.poulpoints` comme identifiant et la signature de débogage de la machine de compilation, **même pour ce build `release`**. Sur la même machine et avec le même keystore de débogage, la mise à jour d'une version précédente compilée ici devrait être acceptée. Si Android refuse la mise à jour à cause de la signature, **exporter les données JSON avant de désinstaller l'application** ; la désinstallation efface les données locales de l'application. Il faudra remplacer la signature de test par une clé de distribution durable avant toute sortie publique.

## Essai de synchronisation

1. Créer une tâche de test distincte sur chaque appareil.
2. Connexion « Poulapp Cloud » sur le PC puis sur le Pixel à **la même instance Supabase et au même compte approuvé**, avec URL HTTPS et clé `sb_publishable_`/`anon`, jamais de `sb_secret_`/`service_role`.
3. Effectuer une sauvegarde JSON avant la première synchronisation, même si les données sont sans importance.
4. Dans chaque application, utiliser « Synchroniser Poulapp Cloud » une première fois manuellement.
5. Vérifier les deux tâches de test sur chaque appareil après synchronisation, puis essayer une modification, une sous-tâche et une suppression.
6. Ne pas modifier la *même* tâche hors ligne sur les deux appareils pour ce premier test ; la résolution de conflits n'a pas encore d'interface.

Les identifiants Supabase ne sont pas incorporés dans le code. Des sessions devront être rouvertes après fermeture de l'app (tokens gardés uniquement en mémoire).

## Limitations

- Compilation Android non validée dans l'environnement de création de cette archive, faute de Flutter/Android SDK ici.
- L'échange entre appareils et le retour de connexion doivent encore être testés.
- Ce paquet sert aux tests, pas à F-Droid : avant publication, signature durable, builds reproductibles et conformité dépendances doivent être vérifiés.
