# Poulpoints 0.6.0 — navigateur

Extraire l’archive Web puis servir son dossier par HTTP sur localhost, ou HTTPS pour un hébergement. Ne pas ouvrir directement index.html comme fichier.

```sh
python3 -m http.server 8080 --bind 127.0.0.1
```

Ouvrir http://127.0.0.1:8080 dans le navigateur. Garder la même adresse et le même port : la base IndexedDB appartient à cette origine. Effacer les données du site ou utiliser une session privée peut supprimer les tâches locales ; exporter régulièrement une sauvegarde.

Compilation depuis les sources :

```sh
flutter build web --release --no-web-resources-cdn
```

Les fichiers à héberger se trouvent dans build/web. La session cloud reste temporaire dans le navigateur. La création hors ligne fonctionne une fois l’application chargée ; le lancement hors ligne d’une PWA installée n’est pas fourni. Le cloud réel et les autres navigateurs restent à valider.

Les réglages de rappel sont conservés et synchronisables, mais aucune notification navigateur n’est programmée. Les rappels natifs s’exécutent sur Android et Linux avec les permissions/le compagnon requis.
