# Validation 0.6.4 — 14 octobre 2026

## Vérifications techniques

- APK Android ARM64 release 0.6.4+17 compilé et installé sur le Pixel sans effacement.
- 13 tests Robolectric réussis, zéro échec : palettes claire/sombre, collection défilante, actions et alarmes.
- Contrôle du DEX release réussi : correctif des constructeurs Room/Worker conservé.
- Aucun changement Dart ; les tests Flutter historiques ne sont pas présentés comme réexécutés.

## Essais réels

- Android 0.6.3 : défilement et fonctionnement du widget confirmés par l’utilisateur.
- Android : rappel normal créé depuis le formulaire, déclenché par Android et reçu visuellement par l’utilisateur. Permissions de notifications et d’alarmes exactes autorisées.
- KDE : création via +, actualisation locale et validation de tâche confirmées par l’utilisateur. Cocher ouvre encore l’application ; ce comportement reste une limite connue.
- Linux : service utilisateur actif et activé au démarrage de session. Envoi de rappels avec projection de test isolée en mode normal et économie d’énergie ; profil performance rétabli. Le redémarrage du service a été testé, pas celui de l’ordinateur.
- Linux : l’utilisateur n’avait pas vu les premières bannières. Une capture ultérieure prouve que l’alerte de diagnostic s’affiche sur l’écran de gauche, près du widget. Cette observation ne valide pas à elle seule tout le parcours de rappel après redémarrage.

## Validation encore à terminer

- Android : rappel en économie de batterie, après redémarrage réel et inspection visuelle du thème sombre sur le lanceur.
- Linux : rappel créé dans l’application, réception après redémarrage réel de Bazzite et ouverture de session.
- KDE : redimensionnement, défilement, filtre et conservation après redémarrage à confirmer visuellement.
- Le widget KDE lit les données locales. La synchronisation cloud nécessite encore l’exécution de l’application.
